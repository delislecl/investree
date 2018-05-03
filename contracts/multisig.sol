pragma solidity ^0.4.0;
import "./ERC20Interface.sol";

contract multisig {
    
    //Clm has autority to propose transactions to participants but no right to vote
    address public Clm;
    
    //Lender has autority for confirming and proposing transactions
    address public Lender;
    
    //Borrower has autority for confirming and proposing transactions
    address public Borrower;
    
    //We store deposits
    struct received_transaction{
        address sender;
        uint amount;
    }
    received_transaction[] public Received_transactions;
    
    //We store pending transactions
    struct pending_transaction {
        uint id_transaction;
        address destination;
        uint amount;
        bool isERC20;
        address ERC20_adress;
        bool isExecuted;
        uint has_Lender_confirmed;
        uint has_Borrower_confirmed;
        uint has_Clm_confirmed;
    }
    pending_transaction[] public Pending_transactions;
    
    //Keep track of last transaction submitted
    uint public last_transaction_id = 0;
    
    //Number of confirmations required
    uint public minimum_confirmations = 2;
    
    //Check sender is a particpant
    modifier onlyParticipants() {
        require(msg.sender == Clm || msg.sender == Borrower || msg.sender == Lender);
        _;
    }
    
    //Check sender is a particpant
    modifier onlyAmountPos(uint amount) {
        require(amount > 0);
        _;
    }
    
    //Check sender is a particpant
    modifier onlyNotYetExecuted(uint id) {
        require(!Pending_transactions[id].isExecuted);
        _;
    }
    
    //Events for important events
    event depositReceived(address sender, uint value);
    event transactionProposed(uint id_transaction, address destination, uint amount, bool isERC20, address ERC20_adress);
    event transactionExecuted(uint id_transaction, address destination, uint amount);
    
    //Constructor, Initialize variables of smart contracts, only called once. 
    constructor(address _Lender, address _Borrower) public {
        Lender = _Lender;
        Borrower = _Borrower;
        Clm = msg.sender;
    }
    
    //Submission function
    function propose_transaction(address destination, uint amount, bool isERC20, address ERC20_adress) public onlyParticipants onlyAmountPos(amount) {
        uint new_id = Pending_transactions.length;
        Pending_transactions.push(pending_transaction(
                new_id, //transaction id
                destination, //address of destination
                amount, //amount
                isERC20, // ERC20 token  or ETH
                ERC20_adress, // Adress or ERC20 contract (enter any address if ETH transaction, will be disregarded)
                false, // isExecuted
                0, // Lender approval
                0, //Borrower approval
                0)); //Community approval
        
        //Confirm transaction for transaction proposer    
        confirm_transaction(new_id);
                
        //Transaction proposed
        emit transactionProposed(new_id, destination, amount, isERC20, ERC20_adress);
        
        last_transaction_id = new_id;
    }
    
    //Confirmation function
    function confirm_transaction(uint transaction_id) public onlyParticipants onlyAmountPos(Pending_transactions[transaction_id].amount) {
        
        if (msg.sender == Lender) {
            Pending_transactions[transaction_id].has_Lender_confirmed = 1;
        }
        
        if (msg.sender == Borrower) {
            Pending_transactions[transaction_id].has_Borrower_confirmed = 1;
        }
        if (msg.sender == Clm) {
            Pending_transactions[transaction_id].has_Clm_confirmed = 1;
        }
        
        uint total_confirmed = get_nb_confirmations(transaction_id);
        if (total_confirmed >= 2) {
            
            //Enough participants confirmed, we proceed
            uint amount_to_transfer = Pending_transactions[transaction_id].amount;
            address address_to_transfer = Pending_transactions[transaction_id].destination;
            
            //Execution
            if (Pending_transactions[transaction_id].isERC20) {
                //ERC20 transaction
                ERC20Interface instance = ERC20Interface(Pending_transactions[transaction_id].ERC20_adress);
                instance.transfer(address_to_transfer, amount_to_transfer);
            } else {
                //ETH transaction
                address_to_transfer.transfer(amount_to_transfer);
            }
            
            //Transaction executed
            Pending_transactions[transaction_id].isExecuted = true;
            emit transactionExecuted(transaction_id, address_to_transfer, amount_to_transfer);
        }
    }
    
    //Alow to receive collateral using contrat adress
    function() public payable {
        Received_transactions.push(received_transaction(msg.sender,msg.value));
    }
    
    //Returns the number of confirmations for a specific transaction
    function get_nb_confirmations(uint transaction_id) public view returns(uint) {
        return Pending_transactions[transaction_id].has_Lender_confirmed + Pending_transactions[transaction_id].has_Borrower_confirmed +  Pending_transactions[transaction_id].has_Clm_confirmed;
    }
}