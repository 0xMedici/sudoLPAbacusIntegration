const { ethers } = require("hardhat");
const { expect } = require("chai");
const {MerkleTree} = require("merkletreejs");
const keccak256 = require("keccak256");
const { concat } = require("ethers/lib/utils");
const { constants } = require("ethers");

async function main() {

    const [deployer] = await ethers.getSigners();
    provider = ethers.getDefaultProvider(5);

    // ------- CONNECT CONTRACTS -------- // 
    //Controller connect
    AbacusController = await ethers.getContractFactory("AbacusController");
    controller = await AbacusController.attach("0x3fFCf56c28ED161281E6555291A509bEDd0E8BaB");
    console.log("Controller:", controller.address);

    //Sudo pool connect
    LSSVMPairMissingEnumerableETH = await ethers.getContractFactory("LSSVMPairMissingEnumerableETH");
    pair = await LSSVMPairMissingEnumerableETH.attach("0x7102431288E4Ca470eeb40b610cD2f934Ec37f65");
    console.log("Pair:", pair.address);

    //Proof checker
    ProofCheck = await ethers.getContractFactory("ProofCheck");
    check = await ProofCheck.attach("0x8Fd6b316FdAA43cA6e6a70d6694cEC37Ca60875d");
    console.log("ProofCheck:", check.address);

    NftFactory = await ethers.getContractFactory("NftFactory");
    // nftFactory = await NftFactory.deploy(
    //     deployer.address,
    //     controller.address,
    //     "0xF0202E9267930aE942F0667dC6d805057328F6dC"
    // );
    nftFactory = await NftFactory.attach("0x90e240A3F80e0B1e8D906B7d6Af16814Ef88222C");
    console.log("NFT factory:", nftFactory.address);

    //SudoNFT connect
    SudoNft = await ethers.getContractFactory("SudoNft");
    sudoNft = await SudoNft.attach('0x11d4f562422eB4Fd779CCb3AaC1D6E3cF633795c');
    console.log("Sudo NFT:", sudoNft.address);
    
    //Lend connect
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach("0xd735f90E6d6707A09c7587574B4266C79cdb9f3d");

    //NFT connect
    ERC721 = await ethers.getContractFactory("ERC721");
    erc721 = await ERC721.attach('0x8971718bca2b7fc86649b84601b17b634ecbdf19');
    console.log("Connected to NFT at:", erc721.address);
    
    //Token connect
    ERC20 = await ethers.getContractFactory("ERC20");
    token = await ERC20.attach("0x30a264A8cd2332C65d1fB17E9701AC4F69c56CD4");

    //Bytes connect
    Bytes = await ethers.getContractFactory("Bytes");
    bytes = await Bytes.attach("0xB07C7e9B6F292A297c970F0eA30016c160894B1B");
    console.log("Bytes:", bytes.address);

    //Vault connect
    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach("0xE63fA886Aab5d84A1e46a89E4248f7bFEd576530");
    Vault = await ethers.getContractFactory("Vault");
    // const initiate = await factory.initiateMultiAssetVault(
    //     "SudoLPTest4"
    // );
    // initiate.wait();
    let vaultAddress = await factory.getPoolAddress("SudoLPTest4");
    let maPool = await Vault.attach(vaultAddress);
    console.log("Pool address:", maPool.address);
    console.log("Pair owner:", await pair.owner());
    console.log("Amount of collect:", (await maPool.collectionAmount()).toString());
    console.log("NFTs in pair pool:", (await erc721.balanceOf(pair.address)).toString());
    let poolStartTime = await maPool.startTime();
    console.log("Start time:", poolStartTime);
    let currentEpoch = Math.floor(
        (Date.now() / 1000 - poolStartTime)
        / parseInt(await maPool.epochLength())
    );
    let futureEpoch = Math.floor(
        (Date.now() / 1000 - poolStartTime + await maPool.epochLength() / 2) 
        / parseInt(await maPool.epochLength())
    );
    console.log(
        "Current payout:", currentEpoch, parseInt(await maPool.getPayoutPerReservation(currentEpoch)) 
    );
    console.log(
        "Future payout:", futureEpoch, parseInt(await maPool.getPayoutPerReservation(futureEpoch)) 
    );
    console.log(
        "Current + 1 payout:", currentEpoch + 1, parseInt(await maPool.getPayoutPerReservation(currentEpoch + 1)) 
    );
    console.log(await erc721.ownerOf(862));
    console.log(await sudoNft.ownerOf(3));
    // console.log(await lend.loans(sudoNft.address, 9));
    // console.log(await sudoNft.pairing(pair.address));

    // ------- EXECUTE FUNCTIONS -------- //

    //WL SudoNFT creator
    // const wlCreator = await nftFactory.whitelistCreator(
    //     [
    //         deployer.address,
    //         "0xE6dC2c1a17b093F4f236Fe8545aCb9D5Ad94334a"
    //     ]
    // );
    // wlCreator.wait();
    // console.log("WL Done");

    //Create SudoNFT
    // const createSudoNFT = await nftFactory.createSudoNFT(
    //     "0x8971718bca2b7fc86649b84601b17b634ecbdf19",
    //     10000
    // );
    // createSudoNFT.wait();
    // console.log("Sudo NFT deployed");
    // console.log("SudoNFT:", await nftFactory.sudoNfts("0x8971718bca2b7fc86649b84601b17b634ecbdf19"));

    // Include NFTs in pool
    // let nftIds = new Array();
    // let nftAddresses = new Array();
    // let nftInfoTracker = [];
    // for(let i = 860; i < 900; i++) {
    //     nftIds.push(i+1);
    //     nftAddresses.push(erc721.address);
    //     let bytesVal = await bytes.getBytes(erc721.address, i + 1);
    //     nftInfoTracker.push(bytesVal);
    // }
    // for(let i = 0; i < 40; i++) {
    //     nftIds.push(i+1);
    //     nftAddresses.push(sudoNft.address);
    //     let bytesVal = await bytes.getBytes(sudoNft.address, i + 1);
    //     nftInfoTracker.push(bytesVal);
    // }
    // console.log("ADDRESS", nftAddresses[42]);
    // console.log("ID:", nftIds[42]);
    // let leaves = nftInfoTracker.map(addr => keccak256(addr));
    // let merkleTree = new MerkleTree(leaves, keccak256, {sortPairs: true});
    // let rootHash = merkleTree.getRoot().toString('hex');
    // rootHash = ("0x").concat(rootHash);
    // console.log("NEWHASH:", rootHash);
    // const include = await maPool.includeNft(
    //     rootHash, nftAddresses, nftIds
    // );
    // include.wait();

    // Begin pool
    // const begin = await maPool.begin(3, 100, 100, 86400, token.address, 100, 10, 3600, 1200);
    // begin.wait();

    // Deposit liquidity
    // const approveToken = await token.approve(maPool.address, (1e15 * 5000).toString());
    // approveToken.wait();
    // const purchase = await maPool.purchase(
    //     deployer.address,
    //     [
    //         '0','1','2','3','4','5','6','7'
    //     ],
    //     [
    //         '300', '300', '300','300', '300','300', '300', '300'
    //     ],
    //     currentEpoch,
    //     currentEpoch + 5,
    // );
    // purchase.wait();
    // console.log("Purchase succesful");

    // Remove liquidity 
    // const sell = await maPool.sell(2);
    // sell.wait();

    //Deposit NFTs
    // const transferNFT = await erc721.transferFrom(deployer.address, pair.address, 862);
    // transferNFT.wait();
    // console.log("NFT transferred!");
    
    // Initiate transfer 
    // const initiateSudoTransfer = await sudoNft.initiatePool([pair.address]);
    // initiateSudoTransfer.wait();
    // console.log("Pool transfer initiated!");

    // Transfer ownership from
    // const transferOwnership = await pair.transferOwnership(
    //     // "0xE6dC2c1a17b093F4f236Fe8545aCb9D5Ad94334a"
    //     sudoNft.address
    // );
    // transferOwnership.wait();
    // console.log("Ownership transferred!");

    // Transfer ownership to
    // const callTransferOwnership = await sudoNft.callTransferOwnership(
    //     pair.address,
    // );
    // callTransferOwnership.wait();

    // Borrow
    // let nftIds = new Array();
    // let nftAddresses = new Array();
    // let nftInfoTracker = [];
    // for(let i = 860; i < 900; i++) {
    //     nftIds.push(i+1);
    //     nftAddresses.push(erc721.address);
    //     let bytesVal = await bytes.getBytes(erc721.address, i + 1);
    //     nftInfoTracker.push(bytesVal);
    // }
    // for(let i = 0; i < 40; i++) {
    //     nftIds.push(i+1);
    //     nftAddresses.push(sudoNft.address);
    //     let bytesVal = await bytes.getBytes(sudoNft.address, i + 1);
    //     nftInfoTracker.push(bytesVal);
    // }
    // let leaves = nftInfoTracker.map(addr => keccak256(addr));
    // let merkleTree = new MerkleTree(leaves, keccak256, {sortPairs: true});
    // let address = nftInfoTracker[42];
    // let hashedAddress = keccak256(address);
    // let proof = merkleTree.getHexProof(hashedAddress);
    // let rootHash = merkleTree.getRoot().toString('hex');
    // rootHash = ("0x").concat(rootHash);
    // let compressedValsFirst = [];
    // let pairs = [
    //     pair.address
    // ];
    // let indices = [
    //     1
    // ];
    // for(let i = 0; i < pairs.length; i++) {
    //     compressedValsFirst.push(await sudoNft.getCompressedPoolVal(pairs, indices));
    // }
    // let compressedValsFinal = [];
    // for(let i = 0; i < pairs.length; i++) {
    //     compressedValsFinal.push(compressedValsFirst[i].toString());
    // }
    // const borrow = await sudoNft.borrow(
    //     maPool.address
    //     , compressedValsFinal // address _sudoPool,
    //     , [proof]// bytes32[][] calldata _merkleProof, 
    //     , [3] // uint256 _lpTokenId,
    //     , ['70000000000000000'] // uint256 _amount
    // );
    // borrow.wait();

    // Pay interest
    // const approveTransfer = await token.approve(sudoNft.address, '700000000000000000000');
    // approveTransfer.wait();
    // const payInterest = await sudoNft.payInterest(
    //     maPool.address // address _lendingContract,
    //     , [sudoNft.address]  // address[] calldata sudoNft address,
    //     , [9] // uint256[] calldata _epoch,
    // );
    // payInterest.wait();

    // Repay
    // const approveRepay = await token.approve(
    //     sudoNft.address, 
    //     '70000000000000000000'
    // );
    // approveRepay.wait();
    // const repay = await sudoNft.repay(
    //     maPool.address // address _lendingContract,
    //     , pair.address // address _sudoPool,
    //     , [3] // uint256 _lpTokenId,
    //     , ['70000000000000000']// uint256 _amount
    // );
    // repay.wait();

    // Liquidate
    // const approveTransfer = await token.approve(sudoNft.address, '7000000000000000000');
    // approveTransfer.wait();
    // const liquidate = await sudoNft.liquidateLp(
    //     maPool.address // address _lendingContract,
    //     , [sudoNft.address] // address[] calldata sudoNft address,
    //     , [9] // uint256 _lpTokenId,
    //     , ['70000000000000000'] // uint256[] calldata _epoch
    // );
    // liquidate.wait();

    //Exchange LP for NFT
    // const exchangeLPforNFT = await sudoNft.exchangeLPforNFT(
    //     pair.address,
    //     [94], // NFT id
    //     [9] // LP token id
    // );
    // exchangeLPforNFT.wait();
    // console.log("LP has been exchange for NFT!");

    //Exchange LP for ETH
    // const exchangeLPforETH = await sudoNft.exchangeLPforETH(
    //     pair.address,
    //     deployer.address,
    //     [9]
    // );
    // exchangeLPforETH.wait();
    // console.log("LP has been exchanged for ETH!");

    //Purchase in Sudo pool
    // let price = await pair.getBuyNFTQuote(1);
    // const purchaseNft = await pair.swapTokenForSpecificNFTs(
    //     [94]
    //     , (price[3]).toString()
    //     , deployer.address
    //     , false
    //     , constants.AddressZero
    //     , { value: (price[3]).toString() }
    // );
    // purchaseNft.wait();
    // console.log("NFT purchased!");

    //Sell to Sudo pool
    // const approveNftTransfer = await erc721.approve(pair.address, 94);
    // approveNftTransfer.wait();
    // let salePrice = await pair.getSellNFTQuote(1);
    // console.log(salePrice[3]);
    // const sellNft = await pair.swapNFTsForToken(
    //     [94]
    //     , (salePrice[3]).toString()
    //     , deployer.address
    //     , false
    //     , constants.AddressZero
    // );
    // sellNft.wait();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
    console.error(error);
    process.exit(1);
    });

