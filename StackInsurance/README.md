# Decentralized Insurance Smart Contract

## Overview

This project is a decentralized insurance platform written in the Clarity programming language for the Stacks blockchain. It allows users to create, manage, and interact with insurance policies and claims without the need for intermediaries, using the trustless nature of blockchain. This contract is inspired by the core functionalities of traditional insurance, enabling decentralized risk assessment, claims management, and payouts.

## Features

- **Policy Creation**: Insurers can create new insurance policies for insured parties by specifying a premium amount and coverage limit.
- **Premium Payment**: Insured parties can submit premium payments to activate their policies.
- **Claim Filing**: Insured parties can file claims based on the coverage amount of their policies.
- **Claim Approval**: Insurers can approve or reject submitted claims.
- **Payout**: Upon claim approval, insured parties are eligible for payouts according to the terms of their policy.

## Contract Structure

The smart contract includes the following key components:

### Data Variables
- **`insured-party`**: The principal (user) who holds the insurance policy.
- **`insurer`**: The principal (user) underwriting the policy.
- **`policy-premium`**: The amount of premium paid by the insured party.
- **`policy-coverage`**: The coverage amount provided by the insurance policy.
- **`eligible-for-payout`**: A boolean flag to check if the insured party is eligible for a payout.

### Data Maps
- **`insurance-policies`**: Stores all active policies, linking the insured party with the policy details (premium, coverage, and active status).
- **`insurance-claims`**: Tracks all claims filed by insured parties, storing the claim amount and its approval status.

### Public Functions
- **`initiate-policy`**: Allows an insurer to create an insurance policy for a specific insured party by defining the premium and coverage amount.
  
  Example:
  ```clarity
  (initiate-policy insurer insured-party 100 1000)
  ```

- **`submit-premium`**: Enables the insured party to pay their premium to activate the policy.

  Example:
  ```clarity
  (submit-premium insured-party)
  ```

- **`submit-claim`**: Allows the insured party to file a claim based on the coverage amount in the policy.

  Example:
  ```clarity
  (submit-claim insured-party 500)
  ```

- **`approve-claim`**: Allows the insurer to approve a filed claim, marking it eligible for payout.

  Example:
  ```clarity
  (approve-claim insured-party)
  ```

- **`release-payout`**: Upon claim approval, this function processes the payout for the insured party.

  Example:
  ```clarity
  (release-payout insured-party)
  ```

## Project Setup

### Prerequisites
- **Stacks Blockchain**: The Clarity smart contract language is native to the Stacks blockchain, so you need to set up a Stacks node or use a development environment like [Clarinet](https://github.com/hirosystems/clarinet).
- **Clarity Tools**: Install Clarity tools like Clarinet to compile and test the contract locally.

### Usage

1. **Deploy the contract**: After compiling, deploy the contract to the Stacks testnet or mainnet.

2. **Interact with the contract**: Use Clarity smart contract calls to interact with the deployed contract. For example, to initiate a new policy:
   ```clarity
   (contract-call? .insurance initiate-policy tx-sender 100 1000)
   ```

3. **Monitor Transactions**: Check the Stacks Explorer to verify transactions and contract interactions.

## Example Use Case

1. **Insurer** creates a policy for an insured party by setting a premium and coverage amount.
2. The **insured party** submits the premium payment to activate the policy.
3. In the event of a claimable event, the **insured party** files a claim.
4. The **insurer** reviews and approves the claim.
5. Upon approval, the **insured party** can receive a payout based on the claim amount.

## Development Notes

- **Clarity Language**: Clarity is a decidable language, meaning that the execution of a function or contract can be predicted with certainty, which makes it ideal for smart contracts where trust and security are paramount.
  
- **No Loops or Recursion**: Clarity does not have loops or recursion, so state management and logic should be carefully constructed using conditionals and functional composition.

- **Immutable Data**: Once deployed, smart contracts on Stacks cannot be changed. Make sure the contract logic is thoroughly tested.

## Limitations and Future Enhancements

- **Premium Payment Handling**: The current version only verifies premium submissions; future versions can integrate STX (Stacks Token) payments for premium handling.
- **Advanced Risk Assessment**: More complex risk algorithms and oracle integration could be added to dynamically assess risk.
- **Policy Renewals**: Add functionality to automatically renew policies upon premium submission.
- **Payout Adjustments**: Introduce mechanisms to allow partial payouts or alternative payout conditions.

## Contributing

Contributions are welcome! Feel free to submit a pull request or open an issue to improve the contract or suggest new features.

## Contact

If you have any questions or want to get in touch, feel free to contact us at (owolabenjade@gmail.com)
