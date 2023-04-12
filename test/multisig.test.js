"use strict";

// const ethSigUtil = require("eth-sig-util");
const StandardMultiSig = artifacts.require("StandardMultiSig");
const EfficientMultiSig = artifacts.require("EfficientMultiSig");
const PackedMultiSig = artifacts.require("PackedMultiSig");
const Calculator = artifacts.require("Calculator");

// 0x26fa9f1a6568b42e29b1787c403B3628dFC0C6FE
const PRI_KEY = "8179ce3d00ac1d1d1d38e4f038de00ccd0e0375517164ac5448e3acc847acb34";

contract("MultiSig", function ([deployer, signer1, signer2, signer3, signer4]) {
  let sMultiSig;
  let eMultiSig;
  let pMultiSig;
  let calculator;
  const signers = [signer1, signer2, signer3, signer4];
  const threshold = 3;
  const executeCount = 3;

  beforeEach(async function () {
    sMultiSig = await StandardMultiSig.new(signers, threshold);
    eMultiSig = await EfficientMultiSig.new(signers, threshold);
    pMultiSig = await PackedMultiSig.new(signers, threshold);
    calculator = await Calculator.new();
  });

  describe("execute", () => {
    it(`mesure gas cost ${executeCount} times`, async function () {
      // prettier-ignore
      const abiEncodedCall = web3.eth.abi.encodeFunctionCall({name: "sum", type: "function", inputs: [{ type: "uint256", name: "a" }, { type: "uint256", name: "b" }], }, [1, 2]);

      // execute "executeCount" times
      const sReceipts = [];
      const eReceipts = [];
      const pReceipts = [];
      for (let i = 0; i < executeCount; i++) {
        // StandardMultiSig
        let receipt1 = await sMultiSig.submitTransaction(calculator.address, 0, abiEncodedCall, { from: signer1 });
        let receipt2 = await sMultiSig.confirmTransaction(i, { from: signer1 });
        let receipt3 = await sMultiSig.confirmTransaction(i, { from: signer2 });
        let receipt4 = await sMultiSig.confirmTransaction(i, { from: signer3 });
        let receipt5 = await sMultiSig.executeTransaction(i, { from: signer2 });
        sReceipts.push(
          receipt1.receipt.gasUsed +
            receipt2.receipt.gasUsed +
            receipt3.receipt.gasUsed +
            receipt4.receipt.gasUsed +
            receipt5.receipt.gasUsed
        );

        // EfficientMultiSig
        let hash = await eMultiSig.hashOfCalldata(abiEncodedCall, i);
        receipt1 = await eMultiSig.submitTransaction(calculator.address, 0, hash, { from: signer1 });
        receipt2 = await eMultiSig.confirmTransaction(hash, { from: signer2 });
        receipt3 = await eMultiSig.executeTransaction(abiEncodedCall, i, { from: signer3 });
        eReceipts.push(receipt1.receipt.gasUsed + receipt2.receipt.gasUsed + receipt3.receipt.gasUsed);

        // PackedMultiSig
        hash = await pMultiSig.hashOfCalldata(abiEncodedCall, i);
        receipt1 = await pMultiSig.submitTransaction(0, calculator.address, 0, hash, { from: signer1 });
        receipt2 = await pMultiSig.confirmTransaction(1, hash, { from: signer2 });
        receipt3 = await pMultiSig.executeTransaction(2, abiEncodedCall, i, { from: signer3 });
        pReceipts.push(receipt1.receipt.gasUsed + receipt2.receipt.gasUsed + receipt3.receipt.gasUsed);
      }

      // print gas cost
      for (let i = 0; i < executeCount; i++) {
        // const rRate =
        //   Math.round(((rReceipts[i].receipt.gasUsed - oReceipts[i].receipt.gasUsed) / rReceipts[i].receipt.gasUsed) * 100000) /
        //   1000;
        // const sRate =
        //   Math.round(((sReceipts[i].receipt.gasUsed - oReceipts[i].receipt.gasUsed) / sReceipts[i].receipt.gasUsed) * 100000) /
        //   1000;

        // prettier-ignore
        console.log(
          `[${i + 1}th] standard: ${sReceipts[i]}, efficient: ${eReceipts[i]}, more efficient: ${pReceipts[i]}, robust/optimized: x%, simple/optimized: x%`
        );
      }
    });
  });
});
