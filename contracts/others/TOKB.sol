pragma solidity ^0.4.11;
import "contracts/token/StandardToken.sol";

contract TokenB is StandardToken {

    string public name = "Token B";
    string public symbol = "TOKB";
    uint public decimals = 18;
    uint public INITIAL_SUPPLY = 100 * (10 ** decimals);

    constructor() public {

    address myAddr = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;
    balances[myAddr] = INITIAL_SUPPLY;

  }
}
