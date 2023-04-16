# gas-optimized-multisig
A experlimental gas optimized solidity multisig contract

# PreRequirements
|  Software  |  Version  |
| ---- | ---- |
|  truffle  |  ^v5.x  |
|  ganache |  ^v7.x  |
|  prettier  |  ^v2.x  |
|  eslint  |  ^v8.x  |

## Conditions
- Compare 4 types of contracts.
- The gas cost has been measured for a 3-of-2 configuration of the multisig.
- The multisig allows for approval of a lightweight `pure` function call.

#### Contract Types
1. [StandardMultiSig.sol](./contracts/StandardMultiSig.sol)
    - This is a standard multisig contract that is presented as an example implementation on the Solidity official [website](https://solidity-by-example.org/app/multi-sig-wallet/).
2. [EfficientMultiSig.osl](./contracts/EfficientMultiSig.sol)
    - This is an gas efficient multisig contract, developed based on the `StandardMultiSig`
3. [PackedMultiSig.sol](./contracts/PackedMultiSig.sol)
    - This contract is similar to `EfficientMultiSig`, but it is more gas efficient due to the packing of the Transaction struct. The confirmations flag map has been changed to a bitmap
4. [OptimizedMultiSig](./contracts/OptimizedMultiSig.sol)
    - This is a gas-optimized contract that utilizes inline assembly, developed based on the `PackedMultiSig`."

#### Allowed Function
Sum of two arguments:
```sol
function sum(uint256 a, uint256 b) public pure returns (uint256) {
    return a + b;
}
```

## Result
- Mesure 3 times
  - The initial gas cost is higher due to the initialization of the storage slot for nonces.
- Measure the total gas cost from submitting to executing the transaction.
- Present both the total amount of gas used and the reduction in gas consumption.

| Times  | Standard | Efficient | Packed | Optimized | Standard/Optimized | Efficient/Optimized | Packed/Optimized |
| -- | -- | -- | -- | -- | -- | -- | -- |
|1|429605 gas|165912 gas|120239 gas|119775 gas|72.120 %|27.808 %|0.386 %|
|2|412553 gas|165948 gas|120275 gas|119811 gas|70.959 %|27.802 %|0.386 %|
|3|412553 gas|165948 gas|120275 gas|119811 gas|70.959 %| 27.802 %|0.386 %|
