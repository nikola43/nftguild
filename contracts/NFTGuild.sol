// SPDX-License-Identifier: MIT
/*
PROJECT DEV INFO: Here are a few key development tasks and explanations for Phase 1:

NFT Smart Contract Creation: The first crucial step is to develop an ERC-721 compliant smart contract for NFTs.
This contract should include the minting function, the burn function, and the metadata management function.
The metadata should have the flexibility to add attributes like guild affiliation.
- Done

Token Smart Contract: We need an ERC-20 compliant contract for our native token with a total supply of 100 million tokens.
10% of these tokens should be allocated to the trading liquidity pool, and 90% should go to the mining rewards pool.
- Done

Mining Mechanism: Implement a function that allows NFT owners to mine tokens from the mining rewards pool.
Include a mechanism to adjust the mining fee and reward every seven days.

NFT Vaults: Each NFT needs to be associated with a unique vault where the mined tokens are stored.
The vaults need to be programmed such that tokens can only be withdrawn if the associated NFT is burned.

Community Guilds: Implement functions that allow NFT owners to form guilds or alliances.
This may involve additional metadata for the NFTs and/or additional smart contracts to manage the guilds.
Done

Token Buyback Mechanism: Develop a function that will use 25% of the mining fees for token buybacks from the open market.
The purchased tokens should be burned to reduce the total supply and potentially increase token value.
- Done

Front-End Interface: Build a user-friendly front-end where users can mint NFTs,
join guilds, mine tokens, and perform other interactions with the smart contracts. 
The interface should display all relevant information, such as the user's balance of tokens and NFTs,
current mining fee and reward, and guild affiliation.
*/

pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract NFTGuild is ERC721, Ownable, ERC721Enumerable, ERC721URIStorage {
    //---------- Libraries ----------//
    using Strings for uint256;
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    //---------- Modiffiers ----------//
    modifier OnlyNftOwner(uint256 _tokenId) {
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) {
            revert UserIsNotNftOwner();
        }
        _;
    }

    //---------- Variables ----------//
    uint256 public maxSupply;
    uint256 public miningFee;
    uint256 public miningCycle;
    uint256 public mintingPrice;
    string private baseTokenURI;
    address public routerAddress;
    ERC20Burnable public token;
    Counters.Counter private _tokenIds;

    //---------- Storage -----------//
    struct Guild {
        address owner;
        string name;
        string description;
        address[] members;
    }

    Guild[] private guilds;
    mapping(uint256 => uint256) public vaults;
    AggregatorV3Interface private dataFeeds;

    //---------- Errors -----------//
    error UserIsNotNftOwner();
    error TokenNotExist();
    error InvalidMintAmount();
    error InsufficientEthBalance();

    //---------- Events -----------//
    event Minted(address indexed minter, uint256 indexed tokenId);

    //---------- Constructor ----------//
    constructor(
        address _token,
        address _routerAddress,
        address _dataFeedsAddress
    ) ERC721("NFTGuild", "NFTGuild") {
        maxSupply = 160;
        miningCycle = 7 days;
        miningFee = 1 ether;
        token = ERC20Burnable(_token);
        routerAddress = _routerAddress;
        dataFeeds = AggregatorV3Interface(_dataFeedsAddress);
        mintingPrice = 100 ether; // 100$
    }

    receive() external payable {}

    fallback() external payable {}

    //----------- Internal Functions -----------//
    /**
     * @dev Returns the base URI for the token.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @dev Convert two address in address array.
     * @param tokenA First address.
     * @param tokenB Last address.
     * @return address[] path.
     */
    function _getPath(
        address tokenA,
        address tokenB
    ) private pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        return path;
    }

    /**
     * @dev See {ERC721-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function _getLastPrice() internal view returns (uint256) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = dataFeeds.latestRoundData();
        return uint256(answer);
    }

    /**
     * @dev Swap ETH for tokens.
     * @param amount Amount of ETH to swap.
     */
    function _swapEthForTokens(uint256 amount) internal {
        // get WETH address
        (bool wethSuccess, bytes memory data) = routerAddress.staticcall(
            abi.encodeWithSelector(bytes4(keccak256(bytes("WETH()"))))
        );
        require(wethSuccess, "Error: getWETHAddress");
        address wethAddress = abi.decode(data, (address));

        // swap ETH for tokens
        (bool success, ) = routerAddress.call{value: amount}(
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        bytes(
                            "swapExactETHForTokens(uint256,address[],address,uint256)"
                        )
                    )
                ),
                0,
                _getPath(wethAddress, address(token)),
                address(this),
                block.timestamp + 300
            )
        );
        require(success, "Error: swapNativeForTokens");
    }

    //----------- External Functions -----------//

    function setMintingPrice(uint256 _mintingPrice) external onlyOwner {
        mintingPrice = _mintingPrice;
    }

    /**
     * @dev Set base URI for the token.
     * @param _baseTokenURI URI to set.
     */
    function setBaseURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    //----------- Public Functions -----------//
    /**
     * @dev Mint NFTs.
     * @param _account address for query.
     * @return uint256 array of token ids pertaining to the account.
     */
    function getWalletTokens(
        address _account
    ) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_account);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_account, i);
        }
        return tokenIds;
    }

    /**
     * @dev Return token URI
     * @param tokenId Token id to query.
     */
    function tokenURI(
        uint256 tokenId
    )
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        if (!_exists(tokenId)) {
            revert TokenNotExist();
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        ".json"
                    )
                )
                : "";
    }

    /**
     * @dev Set custom token URI
     * @param _tokenId Token id to update.
     * @param _tokenURI URI to set.
     */
    function setTokenURI(
        uint256 _tokenId,
        string memory _tokenURI
    ) public onlyOwner {
        _setTokenURI(_tokenId, _tokenURI);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function burn(uint256 _tokenId) public OnlyNftOwner(_tokenId) {
        _burn(_tokenId);
    }

    /**
     * @dev Mint NFTs.
     * @param _count Amount of NFTs to mint.
     */
    function mint(uint256 _count) public {
        if (_count < 1 || _tokenIds.current() + _count > maxSupply) {
            revert InvalidMintAmount();
        }

        for (uint256 i = 0; i < _count; i++) {
            uint newTokenID = _tokenIds.current();
            _safeMint(msg.sender, newTokenID);
            _tokenIds.increment();
            vaults[newTokenID] = 0;
            emit Minted(msg.sender, newTokenID);
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Return guilds.
     */
    function getGuilds(
        uint256 _from,
        uint256 _to
    ) public view returns (Guild[] memory) {
        Guild[] memory guilds_ = new Guild[](_to - _from);
        for (uint256 i = _from; i < _to; i++) {
            guilds_[i] = guilds[i];
        }
        return guilds_;
    }

    function getGuild(uint256 _guildId) public view returns (Guild memory) {
        return guilds[_guildId];
    }

    function createGuild(string memory name, string memory description) public {
        if (getWalletTokens(msg.sender).length == 0) {
            revert UserIsNotNftOwner();
        }

        guilds.push(
            Guild({
                owner: msg.sender,
                name: name,
                description: description,
                members: new address[](0)
            })
        );
    }

    /**
     * @dev Exit guild.
     * @param _tokenId Token id to join guild.
     */
    /*
    function exitGuild(uint256 _tokenId) public {
        Guild storage guild = guilds[_tokenId];
        require(_index < guild.length, "index out of bound");
        for (uint i = _index; i < guild.length - 1; i++) {
            guild[i] = guild[i + 1];
        }
        guild.pop();
    }
    */

    /**
     * @dev switch guild.
     */
    function switchGuild(uint256 _fromTokenId, uint256 _toTokenId) public {
        // exitGuild(_fromTokenId);
        joinGuild(_toTokenId);
    }

    function getRequiredEthAmount() public view returns (uint256) {
        return (mintingPrice / uint256(_getLastPrice())) * 1e8;
    }

    /**
     * @dev Join guild.
     * @param _tokenId Token id to join guild.
     */
    function joinGuild(uint256 _tokenId) public OnlyNftOwner(_tokenId) {
        guilds[_tokenId].members.push(msg.sender);
    }

    function mine(uint256 _tokenId) public OnlyNftOwner(_tokenId) {
        vaults[_tokenId] += 1;
    }

    /**
     * @dev Swap ETH for tokens and burn them.
     */
    function buyBack() public onlyOwner {
        uint256 ethBalance = address(this).balance;
        if (ethBalance == 0) revert InsufficientEthBalance();

        uint256 tokenBalance = token.balanceOf(address(this));
        _swapEthForTokens(ethBalance);
        uint256 newTokenBalance = token.balanceOf(address(this));

        token.burn(newTokenBalance.sub(tokenBalance));
    }
}
