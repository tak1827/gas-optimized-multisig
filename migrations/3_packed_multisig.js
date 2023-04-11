const MultiSig = artifacts.require("PackedMultiSig");

module.exports = function (deployer, network, accounts) {
  if (network !== "development") return;

  const signers = [accounts[0], accounts[1], accounts[2]]
  const threshold = 2;
  deployer.deploy(MultiSig, signers, threshold);
};
