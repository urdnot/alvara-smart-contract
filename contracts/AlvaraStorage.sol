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
        442035311901958114253262039277997779368656856254343608684205718628205312,
        4168934543252561356552492013905839484062179059586461823289725382081668069,
        44555949667939575737454117233525195637186969461171686435427493806235189792,
        95409749181617759665478207487868908814917923760273454797193385805242630677028,
        71917865862099451788948165015890869163158145297902900157135354875175346774208,
        1966997761549456938330745341462801184269830324292361445617255452612820992,
        57942203503281351009795651559959916253376742279146197617463531273563475574752,
        248462881635641250566501389789569836799378965120941487444843810588720640,
        3975406106170260009064022236633117388833711189798288726209756392778096640,
        849292674795864265011141799332131459909744407667883024486236160,
        59763658964674158498249623203841626313278871022017728015924453565225052965987,
        11205686055224151158092635641377396914047927831109012469977999416971631990982,
        22637528534753093119078881748656920224920658657519720605739392613708061880724,
        44822744260031998229181632608524857198552361171011557015736024830471613448192
    ];

    uint public constant TOKEN_PRICE = 80000000000000000; // 0.08 ETH
    uint32 private constant PRIME_DELTA = 99133;
    uint16 public constant MAX_TOKENS = 10000;
    uint8 public constant DEVELOPERS_COUNT = 5;
    uint8 public constant RCATEGORIES_COUNT = 10;
    uint8 public constant MAX_ATTRIBUTE_COUNT = 7;
    uint public constant MAX_TOKENS_PER_PUBLIC_MINT = 10; // Only applies during public sale.
    address public constant CHARITY_ADDRESS = 0x0000000000000000000000000000000000000000; //TODO: put charity address!

    mapping(uint256 => uint256) private _data;
    mapping(address => uint) public presaleReservations;

    uint public numPreSaleReservations = 0;
    uint public forDonation = 0;
    uint public RNG_VRF_RESULT;
    uint private randomModifier = 2;
    uint private generatedTokens = 0;

    bytes32 internal vrfkeyHash;
    uint256 internal vrfFee;

    uint32[RCATEGORIES_COUNT] private curCombNumber;
    uint16[RCATEGORIES_COUNT] private curCategories;

    uint public saleState = 0; // 0: closed, 1: presale, 2: public sale.

    constructor()
    ERC721("Alvara NFT", "Alvara")
    VRFConsumerBase(
        0xf0d54349aDdcf704F77AE15b96510dEA15cb7952, // VRF Coordinator
        0x514910771AF9Ca656af840dff83E8264EcF986CA  // LINK Token
        )
    {
        vrfkeyHash = 0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445;
        vrfFee = 2 * 10 ** 18; // 2 LINK (Varies by network)

        _setBaseURI("https://alvara.io/tokens/");
    }

    function requestVRFRandomness() public onlyOwner returns (bytes32 requestId)
    {
        require(curCombNumber[0] == 0, "Already generated!");
        require(LINK.balanceOf(address(this)) >= vrfFee, "Not enough LINK.");
        return requestRandomness(vrfkeyHash, vrfFee);
    }

    // Callback function used by VRF Coordinator
    function fulfillRandomness(bytes32, uint256 _randomness) internal override
    {
        for (uint8 i = 0; i < RCATEGORIES_COUNT; i++)
        {
            curCombNumber[i] = uint32(i * _randomness);
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
        uint16 attrInfo = uint16(load(categoryEntryShift + 20 /*attr info*/, 11/*attr size*/));
        uint16 attrCount = uint16(attrInfo & 0x7);
        uint16 attrStart = uint8(attrInfo >> 3);
        uint16 placeMultiplierShift = 565/*ATTR_TABLE_SHIFT TODO!!!*/ + 36 /*ATTR_ENTRY_SIZE*/ * attrStart + 20 /* PLACE_MODIFIER_SHIFT */;
        uint attrs = load(placeMultiplierShift, 36/*ATTR_ENTRY_SIZE*/ * attrCount - 20);

        for (uint8 i = 0; i < attrCount; i++)
        {
            uint16 placeMultiplier = uint16(attrs);
            attrs >>= 36;
            options <<= 4;
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
            uint16 rangeSize = uint16(allRanges & 0x1fff);
            rangeEnd += rangeSize;
            allRanges >>= 13;

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
        uint16 includedSize = included & 0xf;
        uint16 includedStart = included >> 4;
        curCombNumber[rcid] = uint32((curCombNumber[rcid] + PRIME_DELTA) % includedSize);
        uint16 includedEntryShift = 2311/*INCLUDE_TABLE_SHIFT TODO!!!!*/ + 28 /*INCLUDE_ENTRY_SIZE*/ * (includedStart + uint16(curCombNumber[rcid]));
        options = load(includedEntryShift, 28 /*INCLUDED_ENTRY_SIZE*/);
    }

    function isIncluded(uint16 shift, uint16 size, uint options) private view returns (bool)
    {
        for (uint8 i = 0; i < size; i++)
        {
            uint include = load(shift, 28 /*OPTIONS_DATA_SIZE*/);
            if (include ^ options == 0)
            {
                return true;
            }
            shift += 28 /*INCLUDED_ENTRY_SIZE*/;
        }
        return false;
    }

    function isIgnored(uint16 shift, uint16 size, uint options) private view returns (bool)
    {
        for (uint8 i = 0; i < size; i++)
        {
            uint entry = load(shift, 56 /*IGNORED_ENTRY_SIZE*/);
            uint positionMask = entry & 0xfffffff;
            uint ignore = entry >> 28;

            if ((options & positionMask) ^ ignore == 0)
            {
                return true;
            }

            shift += 56 /*IGNORED_ENTRY_SIZE*/;
        }
        return false;
    }

    function generateNormal(uint16 rcid) private returns (uint options)
    {
        bool isOk = false;
        uint8 attempts = 0;
        uint16 cid = rcid / 2;
        uint info = load(87 /*CATEGORY_ENTRY_SIZE*/ * cid + 31 /*info shift*/, 56 /*info size*/);
        uint32 spaceSize = uint32(info);
        uint16 includedSize = uint16((info >> 32) & 0xf);
        uint16 includedStart = uint8(info >> 36);
        uint16 ignoredSize = uint16((info >> 44) & 0xf);
        uint16 ignoredStart = uint8(info >> 48);
        uint16 ignoredStartShift = 1681 /*IGNORED_TABLE_SHIFT*/ + 56 /*IGNORED_ENTRY_SIZE*/ * ignoredStart;
        uint16 includedStartShift = 2311 /*INCLUDED_TABLE_SHIFT*/ + 28 /*INCLUDED_ENTRY_SIZE*/ * includedStart;

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
        _data[tokenId] = (rcid << 35) + options;
    }

    function rerollDna(uint tokenId) internal
    {
        if (_data[tokenId] & (1 << 40)/*reroll flag*/ == 0)
        {
            uint16 rcid = uint16(_data[tokenId] >> 35);
            uint options = generate(rcid);
            _data[tokenId] = (1 << 40)/*reroll flag*/ + (rcid << 35) + options;
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
        require(numPreSaleReservations.add(numNeeded) <= MAX_TOKENS, "Not enough slots.");
        
        for (uint i = 0; i < _addresses.length; i++)
        {
            presaleReservations[_addresses[i]] += _numPerAddress;
        }
        numPreSaleReservations += numNeeded;
    }

    // Mints tokens.
    function mint(uint _numTokens) public payable
    {
        require(_numTokens > 0, "Minimum number to mint is 1.");
        require(saleState > 0, "Sale not open.");
        require(generatedTokens.add(_numTokens) <= MAX_TOKENS, "Not enough slots.");

        // This line ensures the minter is paying at enough to cover the tokens.
        uint allSum = TOKEN_PRICE.mul(_numTokens);
        require(msg.value >= allSum, "Wrong Ether value.");

        if (saleState == 1)
        {
            require(presaleReservations[msg.sender] >= _numTokens, "Not enough presale slots.");
            presaleReservations[msg.sender] -= _numTokens;
        } else 
        { // 2
            require(_numTokens <= MAX_TOKENS_PER_PUBLIC_MINT, "Tokens per mint exceeded.");
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
        uint256 nftShare = address(this).balance / (totalSupply() - DEVELOPERS_COUNT);
        payable(msg.sender).transfer(nftShare);
    }

    function donateReserved(uint256 tokenId) public payable
    {
        require(tokenId >= DEVELOPERS_COUNT, "Developers tokens cannot be burned");
        require(ERC721.ownerOf(tokenId) == msg.sender, "Caller isn't owner");
        uint256 nftShare = address(this).balance / (totalSupply() - DEVELOPERS_COUNT);
        payable(CHARITY_ADDRESS).transfer(nftShare);
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
            return _data[tokenId] & 0xffffffffff;
        }
        return 0xffffffffff;
    }

    function getMagic() external view returns (uint256)
    {
        return randomModifier * PRIME_DELTA;       
    }
}