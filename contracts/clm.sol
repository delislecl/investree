pragma solidity ^0.4.0;
import "./ERC20Interface.sol";
import "./multisig.sol";
import "./SafeMath.sol";

contract clm {
    
    //EVENTS
    event Collateral_received();
    event Loan_received();
    event Collateral_transfered_to_multisig(uint amount);
    event Loan_transfered_to_borrower(uint amount);
    event Multisig_deployed();
    event Collateral_adjustment_submitted(uint amount);
    event Collateral_adjustment_received();
    event Finished();
    event Defaulted();
    
    //LOAN PARAMETERS
    
    address loan_token_address;
    uint public loan_amount;
    uint loan_fee_amount;
    address collateral_token_address;
    uint public collateral_initial_amount;
    uint public collateral_adjustment_amount;
    uint collateral_adjustment_deadline;
    uint maturity; //in days
    uint days_to_adjust;
    uint begin_time;
    uint public end_time;
    
    address borrower;
    address lender;
    address mediator;
    address public multisig_address;
    multisig multisig_deployed;
    
    //STATE VARIABLES
    
    enum state1 {waiting, validated, returned}
    state1 state_collateral;
    state1 state_loan;
    
    enum state2 {waiting_for_collateral_and_loan, 
        waiting_for_collateral_adjustment, 
        waiting_for_maturity, 
        defaulted,
        finished}
    state2 state_global;
    
    enum tokenType {ETH, ERC20}
    tokenType loan_token_type;
    tokenType collateral_token_type;
    
    //Only allows Borrower, Lender or Mediator
    modifier onlyParticipants() {
        require(msg.sender == borrower || msg.sender == lender || msg.sender == mediator);
        _;
    }
    
    //Only allows Lender
    modifier onlyLender() {
        require(msg.sender == lender);
        _;
    }
    
    //Only allows Borrower
    modifier onlyBorrower() {
        require(msg.sender == borrower);
        _;
    }
    
    //Only allows Mediator
    modifier onlyMediator() {
        require(msg.sender == mediator);
        _;
    }
    
    //Constructor
    constructor(/*address _loan_token_address,
        uint _loan_amount,
        uint _loan_fee_amount,
        address _collateral_token_address,
        uint _collateral_initial_amount,
        uint _maturity,
        uint _days_to_adjust,
        address _borrower,
        address _lender,
        address _mediator*/) public {
            /*loan_token_address = _loan_token_address;
            if (_loan_token_address == 0x0) {
                loan_token_type = tokenType.ETH;
            } else {
                loan_token_type = tokenType.ERC20;
            }
            loan_amount = _loan_amount;
            loan_fee_amount = _loan_fee_amount;
            collateral_token_address = _collateral_token_address;
            if (_collateral_token_address == 0x0) {
                collateral_token_type = tokenType.ETH;
            } else {
                collateral_token_type = tokenType.ERC20;
            }
            collateral_initial_amount = _collateral_initial_amount;
            maturity = _maturity;
            days_to_adjust = _days_to_adjust;
            borrower = _borrower;
            lender = _lender;
            mediator = _mediator;
            begin_time = now;
            end_time = now + maturity * 1 days;
            collateral_adjustment_deadline = end_time;*/
            
            loan_token_address = 0xef55BfAc4228981E850936AAf042951F7b146e41;
            if (loan_token_address == 0x0) {
                loan_token_type = tokenType.ETH;
            } else {
                loan_token_type = tokenType.ERC20;
            }
            loan_amount = 100;
            loan_fee_amount = 10;
            collateral_token_address = 0xdC04977a2078C8FFDf086D618d1f961B6C546222;
            if (collateral_token_address == 0x0) {
                collateral_token_type = tokenType.ETH;
            } else {
                collateral_token_type = tokenType.ERC20;
            }
            collateral_initial_amount = 200;
            maturity = 20;
            days_to_adjust = 2;
            borrower = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;
            lender = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
            mediator = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB;
            begin_time = now;
            end_time = now + maturity * 1 days;
            collateral_adjustment_deadline = end_time;
            
            state_loan = state1.waiting;
            state_collateral = state1.waiting;
            state_global = state2.waiting_for_collateral_and_loan;
    }
    
    // VALIDATE LOAN/COLLATERAL
    
    //Check if contract has received enough collateral tokens
    function validate_collateral() public onlyParticipants {
        require(state_collateral == state1.waiting);
        
        uint collateral_received = get_balance_collateral(this);
        if(collateral_received >= collateral_initial_amount) {
            //We received enough collateral, we are ready to proceed
            state_collateral = state1.validated;
            emit Collateral_received();
            if (state_loan == state1.validated) {
                /*We transfer :
                   - collateral to multisig_adress
                   - loan to borrower*/
                   send_collateral();
                   send_loan();
                   state_global = state2.waiting_for_maturity;
            }
        }
    }
    
    //Check if contract has received enough loan tokens
    function validate_loan() public onlyParticipants {
        require(state_loan == state1.waiting);

        uint loan_received = get_balance_loan(this);
        if(loan_received >= loan_amount) {
            //We received enough loan, we are ready to proceed
            state_loan = state1.validated;
            emit Loan_received();
            if (state_collateral == state1.validated) {
                /*We transfer :
                   - collateral to multisig_adress
                   - loan to borrower*/
                   send_collateral();
                   send_loan();
                   state_global = state2.waiting_for_maturity;
            }
        }
    }
    
    //SEND LOAN/COLLATERAL
    
    //Send loan to borrower
    function send_loan() private {
        require(state_loan == state1.validated && state_collateral == state1.validated);
        transfer_loan(borrower, loan_amount);
        
        emit Loan_transfered_to_borrower(collateral_initial_amount);
    }
    
    //Send collateral to multisig
    function send_collateral() private {
        require(state_loan == state1.validated && state_collateral == state1.validated);
        
        //We create the multisig for collateral_token
        multisig_deployed = new multisig(lender, borrower);
        multisig_address = address(multisig_deployed);
        emit Multisig_deployed();
        
        transfer_collateral(multisig_deployed, collateral_initial_amount);
        
        emit Collateral_transfered_to_multisig(collateral_initial_amount);
    }
    
    //RETURN LOAN/COLLATERAL
    
    //Return loan + fee to lender
    function  return_loan()  public onlyParticipants {
        require(state_loan != state1.returned);
        
        uint loan_received = get_balance_loan(this);
        if(loan_received >= loan_amount + loan_fee_amount) {
            //Return loan to lender
            uint amount_to_transfer = loan_amount + loan_fee_amount;
            transfer_loan(lender, amount_to_transfer);
            state_loan = state1.returned;
            
            //Return collateral
            return_collateral();
        }
    }
    
    //Porpose to return collateral to borrower once loan repaid
    function  return_collateral() private {
        require(state_global == state2.waiting_for_maturity);
        require(state_loan == state1.returned);
        require(state_collateral != state1.returned);
        
        //Propose transaction to multisig to return collateral
            uint total_collateral = get_balance_collateral(multisig_deployed);
            if (collateral_token_type == tokenType.ETH) {
                multisig_deployed.propose_transaction(borrower,total_collateral,false,collateral_token_address);
            } else {
                multisig_deployed.propose_transaction(borrower,total_collateral,true,collateral_token_address);
            }
            
            state_collateral = state1.returned;
            state_global = state2.finished;
            emit Finished();
    }
    
    //Request default
    function request_default() public onlyParticipants {
        
        //Check if loan hasn't been returned
        return_loan();
        
        require(state_global != state2.finished);
        require(state_global != state2.defaulted);
        
        
        //Check if loan expired (case 1)
        if (now > end_time + days_to_adjust * 1 days) {
            
            //DEFAULT PROCESS
            default_process();
        }
        
        //Check if Borrower hasn't adjusted on end_time
        if(state_global == state2.waiting_for_collateral_adjustment) {
            
            //Check if collateral hasn't been sent
            send_collateral_adjustment();
            
            require(now >  collateral_adjustment_deadline);
            require(state_global == state2.waiting_for_collateral_adjustment);
            
            //DEFAULT PROCESS
            default_process();
        }
    }
    
    //COLLATERAL ADJUSTMENT
    
    //Request adjustment of collateral from Borrower
    function request_collateral_adjustment(uint amount) public onlyMediator {
        require(state_loan == state1.validated);
        collateral_adjustment_amount = amount;
        collateral_adjustment_deadline = now + days_to_adjust * 1 days;
        state_collateral = state1.waiting;
        state_global = state2.waiting_for_collateral_adjustment;
        
        emit Collateral_adjustment_submitted(amount);
    }
    
    //Send collateral adjustment
    function send_collateral_adjustment() public onlyParticipants {
        if (state_global == state2.waiting_for_collateral_adjustment) {
            uint collateral_added = get_collateral_received();
            if (collateral_added >= collateral_adjustment_amount) {
               transfer_collateral(multisig_deployed, collateral_adjustment_amount);
               collateral_adjustment_amount = 0;
               collateral_adjustment_deadline = end_time;
               state_collateral = state1.validated;
               state_global = state2.waiting_for_maturity;
               
               emit Collateral_adjustment_received();
            }
        }
    }
    
    //PRIVATE
    
    function default_process() private {
        //DEFAULT PROCESS
            uint total_collateral = get_balance_collateral(multisig_deployed);
            if(collateral_token_type == tokenType.ETH) {
                multisig_deployed.propose_transaction(lender,total_collateral,false,collateral_token_address);
            } else {
                multisig_deployed.propose_transaction(lender,total_collateral,true,collateral_token_address);
            }
            state_global = state2.defaulted;
            
            emit Defaulted();
    }
    
    function transfer_collateral(address address_send, uint amount) private {
 
        if (collateral_token_type == tokenType.ETH) {
            address_send.transfer(amount);
        } else {
            ERC20Interface collateral_token = ERC20Interface(collateral_token_address);
            collateral_token.transfer(address_send, amount);
        }
    }
    
    function transfer_loan(address address_send, uint amount) private {
 
        if (loan_token_type == tokenType.ETH) {
            address_send.transfer(amount);
        } else {
            ERC20Interface loan_token = ERC20Interface(loan_token_address);
            loan_token.transfer(address_send, amount);
        }
    }
    
    //VIEWS
    
    //Functions to check balances
    function get_balance_collateral(address address_check) public view returns(uint) {
        uint collateral;
        if (collateral_token_type == tokenType.ETH) {
            collateral = address_check.balance;
        } else {
            ERC20Interface collateral_token = ERC20Interface(collateral_token_address);
            collateral = collateral_token.balanceOf(address_check);
        }
        return collateral;
    }
    
    function get_balance_loan(address address_check) public view returns(uint) {
        uint loan;
        if (loan_token_type == tokenType.ETH) {
            loan = address_check.balance;
        } else {
            ERC20Interface loan_token = ERC20Interface(loan_token_address);
            loan = loan_token.balanceOf(address_check);
        }
        return loan;
    }
    
    //Get  amount of loan tokens on contract
    function get_loan_received() public view returns(uint) {
        ERC20Interface loan_token = ERC20Interface(loan_token_address);
        return loan_token.balanceOf(this);
    }
    
    //Get  amount of collateral tokens on contract
    function get_collateral_received() public view returns(uint) {
        ERC20Interface collateral_token = ERC20Interface(collateral_token_address);
        return collateral_token.balanceOf(this);
    }
    
    //Get  date now to compare with deadlines
    function get_now() public view returns(uint) {
        return now;
    }
    
    //Get  seconds remaining to maturity
    function get_seconds_to_maturity() public view returns(uint) {
        return end_time-now;
    }
    
    //Get  seconds remaining to maturity
    function get_seconds_to_adjustment_deadline() public view returns(uint) {
        return collateral_adjustment_deadline-now;
    }
    
    //Check states
    function get_state_collateral() public view returns(string) {
        if (state_collateral == state1.waiting) return "waiting";
        if (state_collateral == state1.validated) return "validated";
        if (state_collateral == state1.returned) return "returned";
        return "";
    }
    
    function get_state_loan() public view returns(string) {
        if (state_loan == state1.waiting) return "waiting";
        if (state_loan == state1.validated) return "validated";
        if (state_loan == state1.returned) return "returned";
        return "";
    }
    
    function get_state_global() public view returns(string) {
        if (state_global == state2.waiting_for_collateral_and_loan) return "waiting_for_collateral_and_loan";
        if (state_global == state2.waiting_for_collateral_adjustment) return "waiting_for_collateral_adjustment";
        if (state_global == state2.waiting_for_maturity) return "waiting_for_maturity";
        if (state_global == state2.defaulted) return "defaulted";
        if (state_global == state2.finished) return "finished";
        return "";
    }
    
}
