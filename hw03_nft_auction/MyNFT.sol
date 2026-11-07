// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MyNFT (学员实战大作业组件 1)
 * @dev 基于 OpenZeppelin v5.x 实现的标准 ERC721 NFT 合约
 *
 * 任务目标：
 * 1. 继承 ERC721URIStorage 与 Ownable。
 * 2. 构造函数传递 name, symbol，并将 owner 初始化为 msg.sender（注意 OZ v5 要求 Ownable(msg.sender)）。
 * 3. 实现 mint(address to, string memory uri) 函数：
 *    - 仅限所有者调用 (onlyOwner)；
 *    - 自增 tokenId（建议从 1 开始）；
 *    - 使用 _safeMint(to, tokenId) 铸造代币；
 *    - 使用 _setTokenURI(tokenId, uri) 绑定元数据；
 *    - 返回生成的 tokenId。
 * 4. 注意多重继承的 tokenURI 与 supportsInterface 方法重写。
 */
contract MyNFT is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @notice 铸造一枚新的 NFT
     * @param to 接收 NFT 的地址
     * @param uri NFT 元数据地址 (IPFS/HTTP)
     * @return tokenId 铸造出的 NFT ID
     */
    function mint(address to, string memory uri) external onlyOwner returns (uint256) {
        uint256 tokenId = ++_nextTokenId;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return tokenId;
    }
}
