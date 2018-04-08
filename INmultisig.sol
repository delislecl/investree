pragma solidity ^0.4.0;

contract INmultisig {
    
    //Investree has autority to propose transactions to participants but no right to vote
    address public Investree;
    
    //Lender has autority for confirming transactions
    address public Lender;
    
    //Borrower has autority for confirming transactions
    address public Borrower;
    
    //In case Lender and Borrower disagree, Community will have possibility to confirm a transaction
    address public Community;
    
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
        bool isExecuted;
        uint has_Lender_confirmed;
        uint has_Borrower_confirmed;
        uint has_Community_confirmed;
    }
    pending_transaction[] public Pending_transactions;
    
    //Keep track of last transaction submitted
    uint last_transaction_id = 0;
    
    //Number of confirmations required
    uint minimum_confirmations = 2;
    
    //Events for important events
    event depositReceived(address sender, uint value);
    event transactionProposed(uint id_transaction, address destination, uint amount);
    event transactionExecuted(uint id_transaction, address destination, uint amount);
    
    //Constructor, Initialize variables of smart contracts, only called once. 
    function INmultisig(address _Investree, address _Lender, address _Borrower, address _Community) public payable {
        Investree = _Investree;
        Lender = _Lender;
        Borrower = _Borrower;
        Community = _Community;
    }
    
    //Submission function
    function propose_transaction(address destination, uint amount) public {
        require(msg.sender == Investree);
        require(destination > 0);
        uint new_id = Pending_transactions.length;
        Pending_transactions.push(pending_transaction(
                new_id, //transaction id
                destination, //address of destination
                amount, //amount in wei
                false, // isExecuted
                0, // Lender approval
                0, //Borrower approval
                0)); //Community approval
                
        //Transaction proposed
        emit transactionProposed(new_id, destination, amount);
        
        last_transaction_id = new_id;
    }
    
    //Confirmation function
    function confirm_transaction(uint transaction_id) public payable {
        require(msg.sender == Lender || msg.sender == Borrower || msg.sender == Community);
        require(Pending_transactions[transaction_id].amount > 0);
        require(!Pending_transactions[transaction_id].isExecuted);
        
        if (msg.sender == Lender) {
            Pending_transactions[transaction_id].has_Lender_confirmed = 1;
        }
        
        if (msg.sender == Borrower) {
            Pending_transactions[transaction_id].has_Borrower_confirmed = 1;
        }
        if (msg.sender == Community) {
            Pending_transactions[transaction_id].has_Community_confirmed = 1;
        }
        
        uint total_confirmed = Pending_transactions[transaction_id].has_Lender_confirmed + Pending_transactions[transaction_id].has_Borrower_confirmed +  Pending_transactions[transaction_id].has_Community_confirmed;
        if (total_confirmed >= 2) {
            
            //Enough participants confirmed, we proceed
            uint amount_to_transfer = Pending_transactions[transaction_id].amount;
            address address_to_transfer = Pending_transactions[transaction_id].destination;
            
            //Execution
            address_to_transfer.transfer(amount_to_transfer);
        
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
    function get_nb_confirmations(uint transaction_id) public constant returns(uint) {
        return Pending_transactions[transaction_id].has_Lender_confirmed + Pending_transactions[transaction_id].has_Borrower_confirmed +  Pending_transactions[transaction_id].has_Community_confirmed;
    }
}