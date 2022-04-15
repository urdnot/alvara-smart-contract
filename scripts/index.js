module.exports = async function main (callback)
{
    try
    {
        // Our code will go here
        const AlvaraStorage = artifacts.require('AlvaraStorage');
        const storage = await AlvaraStorage.deployed();
        const accounts = await web3.eth.getAccounts();
        //await storage.genToken();
        // const options = await storage.getOptions(0, { from: accounts[0], gas: 2000000000});
        // const amountOfGas = await storage.callMethod.estimateGas(39, 53);
        // console.log('Gas is', amountOfGas);
        // const ret = await storage.callMethod.call(39, 53);
        // console.log('Ret is', ret.toString());
        ret = await storage.getMagic();
        console.log('Ret is ', ret.toString());
        callback(0);
    } 
    catch (error)
    {
        console.error(error);
        callback(1);
    }
};