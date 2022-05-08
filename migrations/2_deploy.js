const AlvaraStorage = artifacts.require('AlvaraStorage');

module.exports = async function (deployer, network, accounts)
{
  if (network == "development")
  {
    await deployer.deploy(AlvaraStorage);
  }
  else if (network == "rinkeby" || network == "rinkeby-fork")
  {
    // Testnet rinkeby
    await deployer.deploy(AlvaraStorage)
  }
  else
  {
    console.log("Unknown network: ", network);
  }
};