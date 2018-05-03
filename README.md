# Investree Collateral Management Smart Contracts

Below is description of behavior of Investree Collateral Management Smart Contracts.

## Architecture

The contract folder is composed of 4 smart Contracts :
- [factory](contracts/factory.sol) : which is factory contract that will generate instance of clm Contracts when borrower/lender will agree on loan parameters. It will be the only reliable source of clm instances generated.
- [clm](contracts/clm.sol) : contract that will manage the loan process during its life. He will generate a multisignature wallet that will be used to store collateral during loan life.
- [multisig](contracts/multisig.sol) : 2 of 3 multisignature contract that will store collateral. Borrower and Lender will be able to end loan earlier than expected by bypassing clm.
- [ERC20Interface](contracts/ERC20Interface.sol) : Interface for interacting with ERC20 tokens.

## User path

I will go over the different steps of the loan process here to illustrate the mecanism of loan and make integration with front end easier.

First Borrower and Lender will agree on the parameters of the loan. In this example, we will consider they both agreed on the following parameters that will then be sent to factory to create a new clm instance with those parameters.

```
loan_token_address = 0x15e08fa9FE3e3aa3607AC57A29f92b5D8Cb154A2; //ERC20 token "TOKA"
loan_token_type = tokenType.ERC20;
loan_amount = 100;
loan_fee_amount = 10;
collateral_token_address = 0x9635E132729Aa83B126ab8B159194196b5EeB069; //ERC20 token "TOKB"
collateral_token_type = tokenType.ERC20;
collateral_initial_amount = 200;
maturity = 20; // 20 days, beginning at clm creation
days_to_adjust = 2; // 2 days to adjust collateral
borrower = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;
lender = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
mediator = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB; //Address used by Community
```

At this point, an instance of clm has been created with those parameters and particicpants can interact with clm contract.

### 1. Lender/Borrower fund clm with loan/collateral

During the life of the loan, 2 internal State variables (state1) and 1 global State (state2) variable will return loan process status.
When and instance is created, those State variables are initialized at the following values :

```
state_loan = state1.waiting;
state_collateral = state1.waiting;
state_global = state2.waiting_for_collateral_and_loan;
```

To fund the clm instance, participants will have to send the corrcet amount of token to the CLM. For example, here the amount of tokens needed will be :
- 200 "TOKB" from Borrower
- 100 "TOKA" from Lender

The following functions can we used to see the amount of tokens received from Borrower and Lender :

```
 //Get  amount of loan tokens on contract
 function get_loan_received() public view returns(uint) {}

 //Get  amount of collateral tokens on contract
 function get_collateral_received() public view returns(uint) {}
 ```

When Borrower and Lender have sent they tokens, they can respectively call their validation functions :

```
//Check if contract has received enough collateral tokens
function validate_collateral() public onlyParticipants {}

//Check if contract has received enough loan tokens
function validate_loan() public onlyParticipants {}
```
Once a participant validates, the State variable is updated to the "validated" mode :
```
state_collateral = state1.validated;
state_loan = state1.validated;
```
Once both collateral and loan have been validated, Mulitsignature contract is being generated and :
- Loan amount is sent to Borrower
- Collateral amount is sent to multilignature

```
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
```
Global state variable is also being updated : ```state_global = state2.waiting_for_maturity;```
Borrower can now use loan during the loan life and will have to adjust collateral when mediator sends collateral updates.

### 2. Mediator sends collateral adjustments

When Mediator wants to ask the borrower to adjust the amount of collateral, he can use the following functions. If adjustment is positive (borrower needs to add collateral) clm waits for more collateral. If adjustment is negative, clm automatically submit an transaction for adjustment to multisig and borrower can then validate.

```
function request_collateral_adjustment(uint amount) public onlyMediator {
        require(state_loan == state1.validated);
        require(amount > 0);
        
        if (amount > 0){
            collateral_adjustment_amount = amount;
            collateral_adjustment_deadline = now + days_to_adjust * 1 days;
            state_collateral = state1.waiting;
            state_global = state2.waiting_for_collateral_adjustment;
            
            emit Collateral_adjustment_submitted(amount);
        } else {
            //clm propose transaction to multisig to reduce collateral
            if (collateral_token_type == tokenType.ETH) {
                multisig_deployed.propose_transaction(borrower,-amount,false,collateral_token_address);
            } else {
                multisig_deployed.propose_transaction(borrower,-amount,true,collateral_token_address);
            }
        }
    }
```
If amount is positive, the borrower has ```days_to_adjust``` days to send more collateral to clm.
At that point, states variables are the following :

```
state_loan = state1.validated;
state_collateral = state1.waiting;
state_global = state1.waiting_for_collateral_adjustment;
```

Once borrower has added collateral to clm, he can validate its adjustment using :

```
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
```
After that, loan process returns to its normal state and states variables have the following values :

```
state_loan = state1.validated;
state_collateral = state1.validated;
state_global = state1.waiting_for_maturity;
```

### 3. Borrower returns loan

Borrower has till maturity + days_to_adjust (22 days in this example) to return loan amount and premium to clm.
When he has sent loan amount + premium (110 TOKA) to clm, he can then call :

```
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
```
This function will :
- Transfer the loan amount and premium to Lender
- Update loan state variable to "returned"
- Propose and validate a transaction to multisig in order to return collateral to borrower
- Update collateral state variable to "returned"
- Update global state variable to "finished"

Borrower will now have to accept transaction proposed to multisig and he will get his collateral back.
Process is now Finished and state variables have the following values :

```
state_loan = state1.returned;
state_collateral = state1.returned;
state_global = state1.finished;
```
### 4. If Borrower defaults

Their are 2 reasons of default :
- Borrower fails to adjust collateral amount on time
- Borrower fails to return loan and premium on time

In this case, Lender can request a default using the following function :
```
function request_default() public {}
```
In this case, the clm will :
- Porpose and validate a transaction to multisig in order to send collateral to Lender
- Update global state variable to "default"

Process is now Finished and state variables have the following values :
```
state_loan = state1.validated;
state_collateral = state1.validated or state1.waiting;
state_global = state2.finished or state2.waiting_for_collateral_adjustment;
```
