module.exports = async function main (callback)
{
    try
    {
        // Our code will go here
        const AlvaraStorage = artifacts.require('AlvaraStorage');
        const storage = await AlvaraStorage.deployed();
        const accounts = await web3.eth.getAccounts();
        const owner = accounts[0];
        const other = accounts[1];

        for (let i = 0; i < 15; ++i)
        {
            const res = await storage.getData(i);
            console.log(res.toString());
        }

        callback(0);
    } 
    catch (error)
    {
        console.error(error);
        callback(1);
    }
};