pragma solidity ^0.4.17;
import "./clm.sol";

contract factory {
    
    //List of deployed CLMs
    address[] public deployed_clm;

    //Create new CLM
    function create_clm() public {
        address new_clm = new clm();
        deployed_clm.push(new_clm);
    }

    //Return list of deployed CLMs
    //This is the only reliable source of deployed CLMs
    //CLMs not in this list might be malicious modified contract instances !
    function get_deployed_clm() public view returns (address[]) {
        return deployed_clm;
    }
    
}