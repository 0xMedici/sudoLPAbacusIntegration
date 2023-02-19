const { expect } = require("chai");
const { ethers } = require("hardhat");
const {MerkleTree} = require("merkletreejs");
const keccak256 = require("keccak256");
const { concat } = require("ethers/lib/utils");

describe("Sudo integration", function () {
    let
        deployer,
        user1,
        user2,
        AbacusController,
        controller,
        Factory,
        factory,
        token,
        nft1,
        nft2,
        Vault,
        maPool,
        Closure,
        SudoNft,
        sudoNft,
        LSSVMPairFactory,
        sudoFactory,
        LSSVMPair,
        pair,
        nftIds,
        nftAddresses,
        nftInfoTracker
    
    beforeEach(async() => {
        [
            deployer, 
            user1, 
            user2 
        ] = await ethers.getSigners();

        provider = ethers.getDefaultProvider();

        AbacusController = await ethers.getContractFactory("AbacusController");
        controller = await AbacusController.deploy(deployer.address);

        Factory = await ethers.getContractFactory("Factory");
        factory = await Factory.deploy(controller.address);
        await controller.setBeta(3);
        await controller.setFactory(factory.address);
        await controller.addWlUser([deployer.address]);

        ERC721 = await ethers.getContractFactory("ERC721");
        nft1 = await ERC721.deploy("NFT1", "N1");
        nft2 = await ERC721.deploy("NFT2", "N2");
        
        ERC20 = await ethers.getContractFactory("ERC20");
        token = await ERC20.deploy("TKN", "TT");

        LSSVMPairFactory = await ethers.getContractFactory("LSSVMPairFactory");
        sudoFactory = await LSSVMPairFactory.deploy(
            
        );
        SudoNft = await ethers.getContractFactory("SudoNft");
        sudoNft = await SudoNft.deploy(
            deployer.address,
            '0xF0202E9267930aE942F0667dC6d805057328F6dC' // sudo factory address
            , '0x8971718bca2b7fc86649b84601b17b634ecbdf19' // nft collection address 
            , 860 // total token supply
        );
        LSSVMPair = await ethers.getContractFactory("LSSVMPair");
        // pair 
        
        Vault = await ethers.getContractFactory("Vault");
        nftIds = new Array();
        nftAddresses = new Array();
        nftInfoTracker = [];
        for(let i = 0; i < 6; i++) {
            await nft1.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = nft1.address;
            let bytesVal = await bytes.getBytes(nft1.address, i + 1);
            nftInfoTracker.push(bytesVal);
        }
        for(let i = 0; i < 6; i++) {
            await nft2.mintNew();
            nftIds[i] = i + 1;
            nftAddresses[i] = nft2.address;
            let bytesVal = await bytes.getBytes(nft2.address, i + 1);
            nftInfoTracker.push(bytesVal);
        }
        await factory.initiateMultiAssetVault(
            "HelloWorld"
        );
        let vaultAddress = await factory.getPoolAddress("HelloWorld");
        maPool = await Vault.attach(vaultAddress);

        let leaves = nftInfoTracker.map(addr => keccak256(addr));
        let merkleTree = new MerkleTree(leaves, keccak256, {sortPairs: true});
        let rootHash = merkleTree.getRoot().toString('hex');
        rootHash = ("0x").concat(rootHash);
        console.log("NEWHASH:", rootHash);
        await maPool.includeNft(
            rootHash, nftAddresses, nftIds
        );
        await maPool.begin(3, 100, 100, 86400, mockToken.address, 100, 10);
        Closure = await ethers.getContractFactory("Closure");
    });

    it("Proper compilation and setting", async function () {
        console.log("Contracts compiled and controller configured!");
    });
});