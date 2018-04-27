# Investree Collateral Management Smart Contracts

Below is description of behavior of Investree Collateral Management Smart Contracts.

## Architecture

The contract folder is composed of 4 smart Contracts :
- factory.sol : which is factory contract that will generate instance of clm Contracts when borrower/lender will agree on loan parameters. It will be the only reliable source of clm instances generated.
- clm.sol : contract that will manage the loan process during its life. He will generate a multisignature wallet that will be used to store collateral during loan life.
- [multisig.sol](multisig.sol) : 2 of 3 multisignature contract that will store collateral. Borrower and Lender will be able to end loan earlier than expected by bypassing clm.

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
maturity = 20; // 20 days
days_to_adjust = 2; // 2 days to adjust collateral
borrower = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C;
lender = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
mediator = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB;
begin_time = now;
end_time = now + maturity * 1 days;
```
