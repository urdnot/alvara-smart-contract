// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma abicoder v2;

import "@chainlink/contracts/src/v0.7/vendor/SafeMathChainlink.sol";
import "@chainlink/contracts/src/v0.7/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.7/VRFRequestIDBase.sol";
import "@chainlink/contracts/src/v0.7/VRFConsumerBase.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract AlvaraStorage is VRFConsumerBase, ERC721, Ownable
{
    using SafeMath for uint256;

    uint256[14] private data = [
        442089231795292378492553979558389642584151397731854248184706189993443890,
        57899661428658577028311584790063109321392015358818623725042996113118016332773,
        44555949667939578422386304870525408155061496401624472889590588105799239456,
        50885196463875972582136975801266751029221129727518987734643775125486078816775,
        3618518760802193349194717759452661494648182980819855478097313952385353588848,
        57896300172835093587115484151242583914370927693117687649557023238165657421576,
        4088866831934005279866350378079803774965764758490077251699747345481625728,
        65421870149881491619000536920944998198132592280121818326142384336168599552,
        7017695699001931663428269821024085524489137862675062550812086124997413437440,
        112283131184030906614852317136385368391826205800245892425408960556199149897795,
        7244300952591203420517263070455909608367035564863450062630367468387035127936,
        14941149386194694715495202826702456979225969424880580076593311032301672726792,
        30813812809735035576396240623990451011887584697203943917796486177089992523776,
        905537618257756707137082709075435421644945396532852403862059378171764015104
    ];

    //uint public constant TOKEN_PRICE = 80000000000000000; // 0.08 ETH Mainnet
    uint public constant TOKEN_PRICE = 1000000000000000; // 0.001 ETH Rinkeby testnet
    uint32 private constant PRIME_DELTA = 99133;
    uint16 public constant MAX_TOKENS = 10000;
    uint8 public constant DEVELOPERS_COUNT = 5;
    uint8 public constant RCATEGORIES_COUNT = 10;
    uint public constant MAX_TOKENS_PER_PUBLIC_MINT = 10; // Only applies during public sale.
    address public constant CHARITY_ADDRESS = 0xC4debFE1ac7B01E67Afe3D61b2a633A960CAf864; //TODO: For test its my address, it should be changed
    mapping(uint256 => uint256) private _data;
    mapping(address => uint) public presaleReservations;

    uint public forDonation = 0;
    uint private numPreSaleReservations = 0;
    uint private randomModifier = 2;
    uint private generatedTokens = 0;

    bytes32 internal vrfkeyHash;
    uint256 internal vrfFee;

    uint32[RCATEGORIES_COUNT] private curCombNumber;
    uint16[RCATEGORIES_COUNT] private curCategories;

    uint public saleState = 0; // 0: closed, 1: presale, 2: public sale.

    constructor()
    ERC721("Alvara NFT", "Alvara")
    // VRFConsumerBase(
    //     0xf0d54349aDdcf704F77AE15b96510dEA15cb7952, // Mainnet VRF Coordinator
    //     0x514910771AF9Ca656af840dff83E8264EcF986CA  // Mainnet LINK Token address
    //     )
    VRFConsumerBase(
        0x6168499c0cFfCaCD319c818142124B7A15E857ab, // Rinkeby VRF Coordinator
        0x01BE23585060835E02B77ef475b0Cc51aA1e0709 // Rinkeby LINK Token address
        )
    {
        //vrfkeyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445; // Mainnet
        //vrfFee = 2 * 10 ** 18; // 2 LINK (Varies by network)
        vrfkeyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc; // Rinkeby
        vrfFee = 25 * 10 ** 16; // 0.25 LINK (Rinkeby)

        _setBaseURI("https://alvara.io/token/");
    }

    function setBaseURI(string memory uri) public onlyOwner
    {
        _setBaseURI(uri);
    }

    function requestVRFRandomness() public onlyOwner returns (bytes32 requestId)
    {
        require(curCombNumber[0] != 0, "Already generated!");
        require(LINK.balanceOf(address(this)) >= vrfFee, "Not enough LINK");
        return requestRandomness(vrfkeyHash, vrfFee);
    }

    // Callback function used by VRF Coordinator
    function fulfillRandomness(bytes32, uint256 _randomness) internal override
    {
        for (uint8 i = 0; i < RCATEGORIES_COUNT; i++)
        {
            curCombNumber[i] = uint32((i + 1) * _randomness);
        }
    }

    function load(uint16 shift, uint16 bitSize) private view returns(uint)
    {
        uint16 end = shift + bitSize;
        uint16 startId = shift >> 8;
        uint16 finishId = end >> 8;
        if (startId == finishId)
        {
            return (data[startId] << (uint8(shift))) >> (256 - bitSize);
        }
        else
        {
            uint8 sh1 = uint8(shift);
            uint8 sh2 = uint8(end);
            return (((data[startId] << sh1)) >> (sh1 - sh2)) + (data[finishId] >> (256 - sh2));
        }
    }

    function random(uint16 range) private returns(uint16)
    {
        return uint16(uint256(keccak256(abi.encodePacked(
            block.timestamp,
            randomModifier++,
            block.difficulty))) % range);
    }

    function int2Opt(uint16 cid, uint number) private view returns (uint options)
    {
        uint16 categoryEntryShift = 87 /*CATEGORY_ENTRY_SIZE*/ * cid;
        uint16 attrInfo = uint16(load(categoryEntryShift + 20 /*ATTR_START_SHIFT*/, 11/*ATTR_START_SIZE + ATTR_COUNT_SIZE*/));
        uint16 attrCount = uint16(attrInfo & 0x7);
        uint16 attrStart = uint8(attrInfo >> 3 /*ATTR_COUNT_SIZE*/);
        uint16 placeMultiplierShift = 565/*ATTR_TABLE_SHIFT*/ + 36 /*ATTR_ENTRY_SIZE*/ * attrStart + 20 /* PLACE_MULTIPLIER_SHIFT */;
        uint attrs = load(placeMultiplierShift, 36/*ATTR_ENTRY_SIZE*/ * attrCount - 20/*PLACE_MULTIPLIER_SHIFT*/);

        for (uint8 i = 0; i < attrCount; i++)
        {
            uint16 placeMultiplier = uint16(attrs);
            attrs >>= 36 /*ATTR_ENTRY_SIZE*/;
            options <<= 5 /*OPTION_BITSIZE*/;
            options += number / placeMultiplier;
            number = number % placeMultiplier;
        }
    }

    function chooseRandomCategory() private returns (uint16 rcid)
    {
        // #--------------------------------
        // # Random category entry
        // #--------------------------------
        // # rangeSize         13    bits

        uint16 rnd = random(MAX_TOKENS);
        uint allRanges = load(435/*RANDOM_CATEGORY_TABLE_SHIFT*/, 130 /*RANDOM_CATEGORY_TABLE_SIZE*/);
        uint16 rangeEnd;
        for (uint8 i = 0; i < RCATEGORIES_COUNT; i++)
        {
            uint16 rangeSize = uint16(allRanges & 0x1fff/*(1 << RCATEGORY_ENTRY_SIZE) - 1*/);
            rangeEnd += rangeSize;
            allRanges >>= 13/*RCATEGORY_ENTRY_SIZE*/;

            if (rnd < rangeEnd)
            {
                rcid = i;
                 while (curCategories[rcid] == rangeSize)
                 {
                     rcid++;
                     if (rcid >= RCATEGORIES_COUNT)
                     {
                         rcid = 0;
                     }
                 }
                 curCategories[rcid]++;
                 return rcid;
            }
        }
    }

    function generateSpecial(uint16 rcid) private returns (uint options)
    {
        uint16 categoryEntryShift = 87 /*CATEGORY_ENTRY_SIZE*/ * (rcid >> 1);
        uint16 included = uint16(load(categoryEntryShift + 43 /*INCLUDED_START_SHIFT*/, 12 /*INCLUDED_START_SIZE+INCLUDED_SIZE_SIZE*/));
        uint16 includedSize = included & 0xf /*(1 << INCLUDED_SIZE_SIZE) - 1*/;
        uint16 includedStart = included >> 4 /*INCLUDED_SIZE_SIZE*/;
        curCombNumber[rcid] = uint32((curCombNumber[rcid] + PRIME_DELTA) % includedSize);
        uint16 includedEntryShift = 2455/*INCLUDED_TABLE_SHIFT*/ + 35 /*INCLUDE_ENTRY_SIZE*/ * (includedStart + uint16(curCombNumber[rcid]));
        options = load(includedEntryShift, 35 /*INCLUDE_ENTRY_SIZE*/);
    }

    function isIncluded(uint16 shift, uint16 size, uint options) private view returns (bool)
    {
        for (uint8 i = 0; i < size; i++)
        {
            uint include = load(shift, 35 /*OPTIONS_ARRAY_SIZE*/);
            if (include ^ options == 0)
            {
                return true;
            }
            shift += 35 /*INCLUDE_ENTRY_SIZE*/;
        }
        return false;
    }

    function isIgnored(uint16 shift, uint16 size, uint options) private view returns (bool)
    {
        for (uint8 i = 0; i < size; i++)
        {
            uint entry = load(shift, 70 /*IGNORE_ENTRY_SIZE*/);
            uint positionMask = entry & 0x7ffffffff /*(1 << PLACE_MASK_SIZE) - 1*/;
            uint ignore = entry >> 35 /*IGNORE_MASK_SIZE*/;

            if ((options & positionMask) ^ ignore == 0)
            {
                return true;
            }

            shift += 70 /*IGNORE_ENTRY_SIZE*/;
        }
        return false;
    }

    function generateNormal(uint16 rcid) private returns (uint options)
    {
        bool isOk = false;
        uint8 attempts = 0;
        uint16 cid = rcid / 2;
        uint info = load(87 /*CATEGORY_ENTRY_SIZE*/ * cid + 31 /*IGNORED_START_SHIFT*/, 56 /*IGNORED_START_SIZE + IGNORED_SIZE_SIZE + INCLUDED_START_SIZE + INCLUDED_SIZE_SIZE + SPACE_SIZE_SIZE*/);
        uint32 spaceSize = uint32(info);
        uint16 includedSize = uint16((info >> 32/*SPACE_SIZE_SIZE*/) & 0xf /*(1 << INCLUDED_SIZE_SIZE) - 1*/);
        uint16 includedStart = uint8(info >> 36/*SPACE_SIZE_SIZE + INCLUDED_SIZE_SIZE*/);
        uint16 ignoredSize = uint16((info >> 44/*SPACE_SIZE_SIZE + INCLUDED_SIZE_SIZE + INCLUDED_START_SIZE*/) & 0xf/*(1 << IGNORED_SIZE_SIZE) - 1*/);
        uint16 ignoredStart = uint8(info >> 48/*SPACE_SIZE_SIZE + INCLUDED_SIZE_SIZE + INCLUDED_START_SIZE + IGNORED_SIZE_SIZE*/);
        uint16 ignoredStartShift = 1825 /*IGNORED_TABLE_SHIFT*/ + 70 /*IGNORE_ENTRY_SIZE*/ * ignoredStart;
        uint16 includedStartShift = 2455 /*INCLUDED_TABLE_SHIFT*/ + 35 /*INCLUDE_ENTRY_SIZE*/ * includedStart;

        do
        {
            curCombNumber[rcid] = uint32((curCombNumber[rcid] + PRIME_DELTA) % spaceSize);
            options = int2Opt(cid, curCombNumber[rcid]);

            isOk = true;

            if (isIncluded(includedStartShift, includedSize, options))
            {
                // Do nothing here. This block only for sameness
            }
            else if (isIgnored(ignoredStartShift, ignoredSize, options))
            {
                attempts++;
            }
            else
            {
                isOk = true;
            }
        }
        while (attempts < 2 && !isOk);
    }

    function generate(uint16 rcid) internal returns (uint)
    {
        if ((rcid % 2) != 0)
        {
            return generateSpecial(rcid);
        }
        return generateNormal(rcid);
    }

    function generateDna(uint tokenId) internal
    {
        // chose random category
        uint16 rcid = chooseRandomCategory();
        uint options = generate(rcid);
        _data[tokenId] = (uint256(rcid) << 35/*OPTIONS_ARRAY_SIZE*/) | options;
    }

    function rerollDna(uint tokenId) internal
    {
        if (_data[tokenId] & (1 << 40)/*reroll flag*/ == 0)
        {
            uint16 rcid = uint16(_data[tokenId] >> 35/*OPTIONS_ARRAY_SIZE*/);
            uint options = generate(rcid);
            _data[tokenId] = (1 << 40)/*reroll flag*/ | (uint256(rcid) << 35/*OPTIONS_ARRAY_SIZE*/) | options;
        }
    }

    /////////////////////////////////////////////////////////////////////////
    // Sale and mint functions
    ///////////////////////////////////////////////////////////////////////// 
    // Open the pre-sale. Only addresses with pre-sale reservations can mint.
    function openPreSale() external onlyOwner
    {
        saleState = 1;
    }

    // Open the public sale. Any address can mint.
    function openPublicSale() external onlyOwner
    {
        saleState = 2;
    }

    // Close the sale.
    function closeSale() external onlyOwner
    {
        saleState = 0;
    }

    /**
     * The function generates one token for each developer. They have identifiers starting from zero.
     * These tokens cannot be burned, and therefore it is impossible to get money for them, this is 
     * done because money is not paid for their minting
     */
    function developersMint() public onlyOwner
    {
        require(generatedTokens == 0, "Should be the first generated");

        for (uint i = 0; i < DEVELOPERS_COUNT; i++)
        {
            _safeMint(msg.sender, generatedTokens);
            generateDna(generatedTokens);
            generatedTokens++;
        }
    }

    // Reserves pre-sale slots for the addresses.
    function reserveForPreSale(address[] memory _addresses, uint _numPerAddress) public onlyOwner
    {
        uint numNeeded = _numPerAddress.mul(_addresses.length);
        require(numPreSaleReservations.add(numNeeded) <= MAX_TOKENS, "Not enough slots");
        
        for (uint i = 0; i < _addresses.length; i++)
        {
            presaleReservations[_addresses[i]] += _numPerAddress;
        }
        numPreSaleReservations += numNeeded;
    }

    // Mints tokens.
    function mint(uint _numTokens) public payable
    {
        require(_numTokens > 0, "Minimum number to mint is 1");
        require(saleState > 0, "Sale not open");
        require(generatedTokens.add(_numTokens) <= MAX_TOKENS, "Not enough slots");

        // This line ensures the minter is paying at enough to cover the tokens.
        uint allSum = TOKEN_PRICE.mul(_numTokens);
        require(msg.value >= allSum, "Wrong Ether value");

        if (saleState == 1)
        {
            require(presaleReservations[msg.sender] >= _numTokens, "Not enough presale slots");
            presaleReservations[msg.sender] -= _numTokens;
        } else 
        { // 2
            require(_numTokens <= MAX_TOKENS_PER_PUBLIC_MINT, "Tokens per mint exceeded");
        }
        
        for (uint i = 0; i < _numTokens; i++)
        {
            _safeMint(msg.sender, generatedTokens);
            generateDna(generatedTokens);
            generatedTokens++;
        }

        // 50% of the amount received goes to charity.
        // The whole picture can be seen by looking at methods:
        //    -  refundReserved()
        //    -  donateReserved()
        //    -  donate()
        forDonation += allSum.div(2);
    }

    /**
     * Allows you to regenerate a set of attributes once for each token, does nothing when called again
     */
    function reroll(uint tokenId) public
    {
        require(ERC721.ownerOf(tokenId) == msg.sender, "Caller isn't owner");
        rerollDna(tokenId);
    }

    function refundReserved(uint256 tokenId) public payable
    {
        require(tokenId >= DEVELOPERS_COUNT, "Developers tokens cannot be burned");
        require(ERC721.ownerOf(tokenId) == msg.sender, "Caller isn't owner");
        uint256 nftShare = (address(this).balance - forDonation) / (totalSupply() - DEVELOPERS_COUNT);
        payable(msg.sender).transfer(nftShare);
        ERC721._burn(tokenId);
    }

    function donateReserved(uint256 tokenId) public payable
    {
        require(tokenId >= DEVELOPERS_COUNT, "Developers tokens cannot be burned");
        require(ERC721.ownerOf(tokenId) == msg.sender, "Caller isn't owner");
        uint256 nftShare = (address(this).balance - forDonation) / (totalSupply() - DEVELOPERS_COUNT);
        payable(CHARITY_ADDRESS).transfer(nftShare);
        ERC721._burn(tokenId);
    }

    /**
     * Donate to charity address. Can be called multiple times, each time will 
     * donate 50% of the proceeds from the previous call to this function
     */
    function donate() public payable onlyOwner
    {
        payable(CHARITY_ADDRESS).transfer(forDonation);
        forDonation = 0;
    }

    function getData(uint256 tokenId) public view returns (uint256)
    {
        if (ERC721._exists(tokenId))
        {
            return _data[tokenId] & 0x1ffffffffff;
        }
        return 0x1ffffffffff;
    }
}