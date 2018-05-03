pragma solidity ^0.4.11;
import "zeppelin/token/StandardToken.sol";

contract TokenA is StandardToken {

    string public name = "Token A";
    string public symbol = "TOKA";
    uint public decimals = 18;
    uint public INITIAL_SUPPLY = 100 * (10 ** decimals);

    constructor() public {

    address myAddr = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
    balances[myAddr] = INITIAL_SUPPLY;

  }
}
