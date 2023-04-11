"use strict";

// const ethSigUtil = require("eth-sig-util");
const StandardMultiSig = artifacts.require("StandardMultiSig");
const Calculator = artifacts.require("Calculator");

// 0x26fa9f1a6568b42e29b1787c403B3628dFC0C6FE
const PRI_KEY = "8179ce3d00ac1d1d1d38e4f038de00ccd0e0375517164ac5448e3acc847acb34";

contract("MultiSig", function ([deployer, signer1, signer2, signer3, relayee]) {
  const relayeeWallet = web3.eth.accounts.privateKeyToAccount(PRI_KEY);
  let sMultiSig;
  let calculator;
  const signers = [signer1, signer2, signer3];
  const threshold = 2;
  const executeCount = 3;

  beforeEach(async function () {
    sMultiSig = await StandardMultiSig.new(signers, threshold);
    calculator = await Calculator.new();
  });

  describe("execute", () => {
    it(`mesure gas cost ${executeCount} times`, async function () {
      // prettier-ignore
      const abiEncodedCall = web3.eth.abi.encodeFunctionCall({name: "sum", type: "function", inputs: [{ type: "uint256", name: "a" }, { type: "uint256", name: "b" }], }, [1, 2]);

      // execute "executeCount" times
      const sReceipts = [];
      for (let i = 0; i < executeCount; i++) {
        // StandardMultiSig
        let receipt1 = await sMultiSig.submitTransaction(calculator.address, 0, abiEncodedCall, { from: signer1 });
        let receipt2 = await sMultiSig.confirmTransaction(i, { from: signer1 });
        let receipt3 = await sMultiSig.confirmTransaction(i, { from: signer2 });
        let receipt4 = await sMultiSig.executeTransaction(i, { from: signer1 });
        sReceipts.push(
          receipt1.receipt.gasUsed + receipt2.receipt.gasUsed + receipt3.receipt.gasUsed + receipt4.receipt.gasUsed
        );
      }

      // print gas cost
      for (let i = 0; i < executeCount; i++) {
        // const rRate =
        //   Math.round(((rReceipts[i].receipt.gasUsed - oReceipts[i].receipt.gasUsed) / rReceipts[i].receipt.gasUsed) * 100000) /
        //   1000;
        // const sRate =
        //   Math.round(((sReceipts[i].receipt.gasUsed - oReceipts[i].receipt.gasUsed) / sReceipts[i].receipt.gasUsed) * 100000) /
        //   1000;
        console.log(
          `[${i + 1} times] standard: ${sReceipts[i]}, simple: x, optimized: x, robust/optimized: x%, simple/optimized: x%`
        );
      }
    });
  });
});
