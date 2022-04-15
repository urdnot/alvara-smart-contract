const AlvaraStorage = artifacts.require('AlvaraStorage');

module.exports = async function (deployer) {
  await deployer.deploy(AlvaraStorage);
};