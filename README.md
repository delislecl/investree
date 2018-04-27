# Investree Collateral Management Smart Contracts

Below is description of behavior of Investree Collateral Management Smart Contracts.

## Architecture

The contract folder is composed of 4 smart Contracts :
- factory.sol : which is factory contract that will generate instance of clm Contracts when borrower/lender will agree on loan parameters. It will be the only reliable source of clm instances generated.
- clm.sol : contract that will manage the loan process during its life. He will generate a multisignature wallet that will be used to store collateral during loan life.
- multisig.sol : 2 of 3 multisignature contract that will store collateral. Borrower and Lender will be able to end loan earlier than expected by bypassing clm.
