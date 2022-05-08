module.exports = async function main (callback)
{
    try
    {
        // Our code will go here
        const AlvaraStorage = artifacts.require('AlvaraStorage');
        const storage = await AlvaraStorage.deployed();
        const accounts = await web3.eth.getAccounts();
        const owner = accounts[0];
        const DEVELOPERS_COUNT = (await storage.DEVELOPERS_COUNT()).toNumber();

        console.log('Start to init smart contract state...');
        console.log('Developers count: ', DEVELOPERS_COUNT);
        console.log('Owner account: ', owner);
        console.log('Total supply: ', (await storage.totalSupply()).toString());

        // 1. Set Base URI
        await storage.setBaseURI('https://2cf1-188-122-0-10.eu.ngrok.io/token/');
        console.log('Base URI is set');

        // // 2. Request randomness
        // await storage.requestVRFRandomness();
        // console.log('Randomness is requested');

        // 3. developersMint()
        await storage.developersMint({ from: owner });
        console.log('Developers mint done');

        // 4. Open Presale
        await storage.openPublicSale();
        console.log('Pulblic sale is opened');
        
        const COUNT = 10;
        // 5. Mint COUNT tokens
        const price = await storage.TOKEN_PRICE();
        for (let i = 0; i < COUNT; i++)
        {
            await storage.mint(1, { from: owner, value: price });
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