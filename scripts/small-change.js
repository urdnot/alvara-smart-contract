module.exports = async function main (callback)
{
    try
    {
        // Our code will go here
        const AlvaraStorage = artifacts.require('AlvaraStorage');
        const storage = await AlvaraStorage.deployed();

        console.log('Start to init smart contract state...');

        await storage.setBaseURI('https://2cf1-188-122-0-10.eu.ngrok.io/token/');
        console.log('Base URI is set');

        console.log('Finish');

        callback(0);
    } 
    catch (error)
    {
        console.error(error);
        callback(1);
    }
};