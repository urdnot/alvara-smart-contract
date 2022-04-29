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
        const DEVELOPERS_COUNT = (await storage.DEVELOPERS_COUNT()).toNumber();

        console.log('Start to init smart contract state...')

        // 1. developersMint()
        await storage.developersMint({ from: owner });
        console.log('Developers mint done');

        // 2. Open Presale
        await storage.openPublicSale();
        console.log('Pulblic sale is opened');
        
        const COUNT = 10;
        // 3. Mint COUNT tokens
        const price = await storage.TOKEN_PRICE();
        for (let i = 0; i < COUNT; i++)
        {
            await storage.mint(1, { from: other, value: price });
            console.log(i + 1, '-th minted');
        }
        const supply = (await storage.totalSupply()).toNumber();
        console.log('Supply check');
        if (supply == DEVELOPERS_COUNT + COUNT)
        {
            console.log('Ok');
        }
        else
        {
            console.log('Error: supply == ', supply);
        }
        console.log('Finish');

        callback(0);
    } 
    catch (error)
    {
        console.error(error);
        callback(1);
    }
};