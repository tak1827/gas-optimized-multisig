const MultiSig = artifacts.require("EfficientMultiSig");

module.exports = function (deployer, network, accounts) {
  if (network !== "development") return;

  const signers = [accounts[0], accounts[1], accounts[2]]
  const threshold = 2;
  deployer.deploy(MultiSig, signers, threshold);
};
