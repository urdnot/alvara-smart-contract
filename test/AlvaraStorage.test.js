// test/AlvaraStorage.test.js
// Load dependencies
const { expect } = require('chai');
const { BN, expectRevert, balance } = require('@openzeppelin/test-helpers');

const AlvaraStorage = artifacts.require('AlvaraStorage');

// Start test block
contract('AlvaraStorage', function ([ owner, other ])
{
  beforeEach(async function ()
  {
    this.storage = await AlvaraStorage.new();
    this.accounts = await web3.eth.getAccounts();
    this.TOKEN_PRICE = await this.storage.TOKEN_PRICE();
    this.MAX_TOKENS = await this.storage.MAX_TOKENS();
    this.DEVELOPERS_COUNT = await this.storage.DEVELOPERS_COUNT();
    this.CHARITY_ADDRESS = await this.storage.CHARITY_ADDRESS();
  });

  it('Sale state changing', async function ()
  {
    // Check initial value
    expect((await this.storage.saleState()).toString()).to.equal('0');

    // Open presale
    await this.storage.openPreSale();
    expect((await this.storage.saleState()).toString()).to.equal('1');

    // Open public sale
    await this.storage.openPublicSale();
    expect((await this.storage.saleState()).toString()).to.equal('2');

    // Close sale
    await this.storage.closeSale();
    expect((await this.storage.saleState()).toString()).to.equal('0');
  });

  it('Not whitelisted mint on presale', async function ()
  {
    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);
    await this.storage.openPreSale();
    await expectRevert(
      this.storage.mint(COUNT, { from: other, value: VALUE }),
      'Not enough presale slots'
    );
  });

  it('Reserve for presale and mint', async function ()
  {
    const COUNT = 3;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);
    await this.storage.reserveForPreSale([ other ], COUNT, { from: owner });
    await this.storage.openPreSale();
    await this.storage.mint(COUNT, { from: other, value: VALUE });

    for (let i = 0; i < COUNT; i++)
    {
      expect(await this.storage.ownerOf(i)).to.equal(other);
    }
  });

  it('Attempt to reserve more than the remaining tokens', async function ()
  {
    const TOO_MANY = this.MAX_TOKENS.clone().iaddn(1);
    await expectRevert(
      this.storage.reserveForPreSale([ other ], TOO_MANY, { from: owner }),
      'Not enough slots'
    );
  });

  it('Mint restrictions', async function ()
  {
    // Attempt to mint when sale is not open
    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);
    await expectRevert(
      this.storage.mint(COUNT, { from: other, value: VALUE }),
      'Sale not open'
    );    

    // Attempt to mint zero tokens
    const ZERO_COUNT = 0;
    await this.storage.openPublicSale();
    await expectRevert(
      this.storage.mint(ZERO_COUNT, { from: other, value: this.TOKEN_PRICE }),
      'Minimum number to mint is 1'
    );

    // // Attempt to mint more than the remaining tokens
    const TOO_MANY = this.MAX_TOKENS.clone().iaddn(1);
    const TOO_VALUE = this.TOKEN_PRICE.clone().imul(TOO_MANY);
    await expectRevert(
      this.storage.mint(TOO_MANY, { from: other, value: TOO_VALUE }),
      'Not enough slots'
    );
    
    // Not enough eth for mint
    const NOT_ENOUGH_VALUE = this.TOKEN_PRICE.clone().imuln(COUNT).isubn(1);
    await expectRevert(
      this.storage.mint(COUNT, { from: other, value: NOT_ENOUGH_VALUE }),
      'Wrong Ether value'
    );
  });

  it('Not enough presale slots', async function ()
  {
    const FOR_RESERVE = 3;
    const FOR_MINT = FOR_RESERVE + 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(FOR_MINT);

    await this.storage.reserveForPreSale([ other ], FOR_RESERVE, { from: owner });
    await this.storage.openPreSale();
    await expectRevert(
      this.storage.mint(FOR_MINT, { from: other, value: VALUE }),
      'Not enough presale slots'
    );
  });

  it('Tokens per public mint exceeded', async function ()
  {
    const MAX_TOKENS_PER_PUBLIC_MINT = await this.storage.MAX_TOKENS_PER_PUBLIC_MINT();
    const COUNT = MAX_TOKENS_PER_PUBLIC_MINT.clone().iaddn(1);
    const VALUE = this.TOKEN_PRICE.clone().imul(COUNT);

    await this.storage.openPublicSale();
    await expectRevert(
      this.storage.mint(COUNT, { from: other, value: VALUE}),
      'Tokens per mint exceeded'
    );
  });

  it('Normal mint changes', async function ()
  {
    const COUNT = 3;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);
    const HALF_VALUE = VALUE.clone().idivn(2);

    await this.storage.openPublicSale();
    await this.storage.mint(COUNT, { from: other, value: VALUE });
    expect(await this.storage.forDonation()).to.be.bignumber.equal(HALF_VALUE);
    expect(await balance.current(this.storage.address)).to.be.bignumber.equal(VALUE);
    expect(await this.storage.totalSupply()).to.be.bignumber.equal(new BN(COUNT));

    for (let i = 0; i < COUNT; i++)
    {
      expect(await this.storage.ownerOf(i)).to.equal(other);
    }
  });

  it('Developers mint is not first generated', async function ()
  {
    const PRE_DEV_MINT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(PRE_DEV_MINT);

    await this.storage.openPublicSale();
    await this.storage.mint(PRE_DEV_MINT, { from: other, value: VALUE });
    await expectRevert(
      this.storage.developersMint(),
      'Should be the first generated'
    );
  });
  
  it('Developers mint', async function ()
  {
    await this.storage.developersMint();
    const DEVELOPERS_COUNT = await this.storage.DEVELOPERS_COUNT();
    expect(await this.storage.totalSupply()).to.be.bignumber.equal(DEVELOPERS_COUNT);
    expect(await this.storage.forDonation()).to.be.bignumber.equal(new BN(0));
  });
  
  it('Get data for not exist token', async function ()
  {
    expect(await this.storage.getData(0)).to.be.bignumber.equal(new BN(0x1ffffffffff));
  });
  
  it('Get data for exist token and check it', async function ()
  {
    const MAX_ATTR_COUNT = 7;
    const RCATEGORIES_COUNT = 10;
    const MAX_OPTIONS_COUNT = 10;
    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);

    await this.storage.openPublicSale();
    await this.storage.mint(COUNT, { from: other, value: VALUE });
    let data = BigInt((await this.storage.getData(0)).toNumber());
    expect(data).not.equal(0x1ffffffffffn);

    let ops = [];
    for (let i = 0; i < MAX_ATTR_COUNT; i++)
    {
      let attr = Number(data & 0x1fn);
      data = data >> 5n;
      expect(attr).lessThan(MAX_OPTIONS_COUNT);
      ops.push(attr);
    }
    let rcat = Number(data & 0x1fn);
    data = data >> 5n;
    expect(rcat).lessThan(RCATEGORIES_COUNT);

    // reroll flag shouldn't be set
    let reroll_flag = Number(data & 0x1n);
    expect(reroll_flag).to.equal(0);
  });

  it('Reroll can be called only by token owner', async function ()
  {
    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);

    await this.storage.openPublicSale();
    await this.storage.mint(COUNT, { from: other, value: VALUE });
    await expectRevert(
      this.storage.reroll(0, { from: owner }),
      "Caller isn't owner"
    );
  });
  
  it('Mint reroll and check token data', async function ()
  {
    const MAX_ATTR_COUNT = 7;
    const RCATEGORIES_COUNT = 10;
    const MAX_OPTIONS_COUNT = 10;
    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);

    await this.storage.openPublicSale();
    await this.storage.mint(COUNT, { from: other, value: VALUE });
    const origin = await this.storage.getData(0);
    await this.storage.reroll(0, { from: other });
    const rerolled = await this.storage.getData(0);

    // check that rerolled data doesn't equal to origin
    expect(rerolled).to.be.bignumber.not.equal(origin);

    // check rerolled data correctness
    let data = BigInt(rerolled.toNumber());
    expect(data).not.equal(0x1ffffffffffn);

    let ops = [];
    for (let i = 0; i < MAX_ATTR_COUNT; i++)
    {
      let attr = Number(data & 0x1fn);
      data = data >> 5n;
      expect(attr).lessThan(MAX_OPTIONS_COUNT);
      ops.push(attr);
    }
    let rcat = Number(data & 0x1fn);
    data = data >> 5n;
    expect(rcat).lessThan(RCATEGORIES_COUNT);

    // reroll flag should be set
    let reroll_flag = Number(data & 0x1n);
    expect(reroll_flag).to.equal(0x1);
  });

  it('Refund reserved restrictions', async function ()
  {
    await this.storage.developersMint();
    await expectRevert(
      this.storage.refundReserved(0),
      'Developers tokens cannot be burned'
    );

    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);
    await this.storage.openPublicSale();
    await this.storage.mint(COUNT, {from: other, value: VALUE});
    await expectRevert(
      this.storage.refundReserved(0, {from: owner}),
      'Developers tokens cannot be burned'
    );
  });

  it('Donate reserved restrictions', async function ()
  {
    await this.storage.developersMint();
    await expectRevert(
      this.storage.donateReserved(0),
      'Developers tokens cannot be burned'
    );

    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);
    await this.storage.openPublicSale();
    await this.storage.mint(COUNT, {from: other, value: VALUE});
    await expectRevert(
      this.storage.donateReserved(0, {from: owner}),
      'Developers tokens cannot be burned'
    );
  });

  it('Refund reserved token', async function ()
  {
    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);
    const HALF_VALUE = this.TOKEN_PRICE.clone().idivn(2);
    const TOKEN_ID = this.DEVELOPERS_COUNT;

    await this.storage.developersMint();
    await this.storage.openPublicSale();
    await this.storage.mint(COUNT, { from: other, value: VALUE });
    const tracker = await balance.tracker(other);
    await this.storage.refundReserved(TOKEN_ID, { from: other });
    const { delta, fees } = await tracker.deltaWithFees();
    expect(delta.iadd(fees)).to.be.bignumber.equal(HALF_VALUE);
    expect(await this.storage.totalSupply()).to.be.bignumber.equal(this.DEVELOPERS_COUNT);
    await expectRevert(
      this.storage.ownerOf(TOKEN_ID),
      'ERC721: owner query for nonexistent token'
    );
  });

  it('Donate reserved token', async function ()
  {
    /////////////////////////////////////////////////////////////////////////
    // This test work only if CHARITY_ADDRESS exist in ganache environment!!!
    /////////////////////////////////////////////////////////////////////////
    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);
    const HALF_VALUE = this.TOKEN_PRICE.clone().idivn(2);
    const TOKEN_ID = this.DEVELOPERS_COUNT;

    await this.storage.developersMint();
    await this.storage.openPublicSale();
    await this.storage.mint(COUNT, { from: other, value: VALUE });
    const tracker = await balance.tracker(this.CHARITY_ADDRESS);
    await this.storage.donateReserved(TOKEN_ID, { from: other });
    const delta = await tracker.delta();
    expect(delta).to.be.bignumber.equal(HALF_VALUE);
    expect(await this.storage.totalSupply()).to.be.bignumber.equal(this.DEVELOPERS_COUNT);
    await expectRevert(
      this.storage.ownerOf(TOKEN_ID),
      'ERC721: owner query for nonexistent token'
    );
  });

  it('Donate send to CHARITY_ADDRESS', async function ()
  {
    /////////////////////////////////////////////////////////////////////////
    // This test work only if CHARITY_ADDRESS exist in ganache environment!!!
    /////////////////////////////////////////////////////////////////////////
    const COUNT = 1;
    const VALUE = this.TOKEN_PRICE.clone().imuln(COUNT);
    const HALF_VALUE = this.TOKEN_PRICE.clone().idivn(2);

    await this.storage.developersMint();
    await this.storage.openPublicSale();
    await this.storage.mint(COUNT, { from: other, value: VALUE });
    const tracker = await balance.tracker(this.CHARITY_ADDRESS);
    await this.storage.donate();
    const delta = await tracker.delta();
    expect(delta).to.be.bignumber.equal(HALF_VALUE);
  });  
});