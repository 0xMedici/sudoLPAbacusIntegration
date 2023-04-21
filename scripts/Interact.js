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
    controller = await AbacusController.attach("0x80B00d4F909f6f0878C058eAa22570151ec78599");
    console.log("Controller:", controller.address);

    //Factory connect
    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach("0x4A958F274Eb133BD888B40df59Ef7a639CB9D72F");
    console.log("Factory:", factory.address);
    
    //Lend connect
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach("0xF210732b06c50CBdb362E96BF4C72fB94f141f85");
    console.log("Lend:", lend.address);

    NftFactory = await ethers.getContractFactory("NftFactory");
    // nftFactory = await NftFactory.deploy(
    //     deployer.address,
    //     controller.address,
    //     "0xF0202E9267930aE942F0667dC6d805057328F6dC"
    // );
    nftFactory = await NftFactory.attach("0xf9991364010Cd51aEAC829Cd78a8c1DaAFf9E9A2");
    console.log("SudoNFT factory:", nftFactory.address);

    //Proof checker
    ProofCheck = await ethers.getContractFactory("ProofCheck");
    check = await ProofCheck.attach("0x8Fd6b316FdAA43cA6e6a70d6694cEC37Ca60875d");
    console.log("ProofCheck:", check.address);

    //Bytes connect
    Bytes = await ethers.getContractFactory("Bytes");
    bytes = await Bytes.attach("0xB07C7e9B6F292A297c970F0eA30016c160894B1B");
    console.log("Bytes:", bytes.address);

    //Sudo pool connect
    LSSVMPairMissingEnumerableETH = await ethers.getContractFactory("LSSVMPairMissingEnumerableETH");
    pair = await LSSVMPairMissingEnumerableETH.attach("0xd73b899e09221d1f3cb7F8A3e70e78d725ee78e3");
    console.log("Pair:", pair.address);

    //SudoNFT connect
    SudoNft = await ethers.getContractFactory("SudoNft");
    sudoNft = await SudoNft.attach('0xD49B9A9667D4CE7B868bCDB8C3Bc4850b672E5fd');
    console.log("Sudo NFT:", sudoNft.address);

    //NFT connect
    ERC721 = await ethers.getContractFactory("ERC721");
    erc721 = await ERC721.attach('0x8971718bca2b7fc86649b84601b17b634ecbdf19');
    console.log("NFT:", erc721.address);
    
    //Token connect
    ERC20 = await ethers.getContractFactory("ERC20");
    token = await ERC20.attach("0x30a264A8cd2332C65d1fB17E9701AC4F69c56CD4");
    console.log("ERC20:", token.address);

    //Vault connect
    Vault = await ethers.getContractFactory("Vault");
    // const initiate = await factory.initiateMultiAssetVault(
    //     "TestPool1"
    // );
    // initiate.wait();
    // let vaultAddress = await factory.getPoolAddress("TestPool1");
    // let maPool = await Vault.attach(vaultAddress);
    // console.log("Pool address:", maPool.address);
    // console.log("Pair owner:", await pair.owner());
    // console.log("Amount of collect:", (await maPool.collectionAmount()).toString());
    // console.log("NFTs in pair pool:", (await erc721.balanceOf(pair.address)).toString());
    // let poolStartTime = await maPool.startTime();
    // console.log("Start time:", poolStartTime);
    // let currentEpoch = Math.floor(
    //     (Date.now() / 1000 - poolStartTime)
    //     / parseInt(await maPool.epochLength())
    // );
    // let futureEpoch = Math.floor(
    //     (Date.now() / 1000 - poolStartTime + await maPool.epochLength() / 2) 
    //     / parseInt(await maPool.epochLength())
    // );
    // console.log(await maPool.getPayoutPerReservation(currentEpoch));
    // console.log(
    //     "Current payout:", currentEpoch, parseInt(await maPool.getPayoutPerReservation(currentEpoch)) 
    // );
    // console.log(
    //     "Future payout:", futureEpoch, parseInt(await maPool.getPayoutPerReservation(futureEpoch)) 
    // );
    // console.log(
    //     "Current + 1 payout:", currentEpoch + 1, parseInt(await maPool.getPayoutPerReservation(currentEpoch + 1)) 
    // );
    // console.log(
    //     "Current + 2 payout:", currentEpoch + 2, parseInt(await maPool.getPayoutPerReservation(currentEpoch + 2)) 
    // );
    // console.log("Hash:", await maPool.root());
    // console.log(await erc721.ownerOf(1317));

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

    // Remove liquidity 
    // const sell = await maPool.sell(0);
    // sell.wait();

    //Deposit NFTs
    // const transferNFT = await erc721.transferFrom(
    //     deployer.address, 
    //     // pair.address, 
    //     "0xE6dC2c1a17b093F4f236Fe8545aCb9D5Ad94334a",
    //     1321
    // );
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

    // console.log(await sudoNft.pairing(pair.address));
    // console.log((await sudoNft.totalSupply()).toString());
    // console.log(await pair.owner());

    // Borrow
    // let nftIds = new Array();
    // let nftAddresses = new Array();
    // let nftInfoTracker = [];
    // for(let i = 800; i < 1300; i++) {
    //     nftIds.push(i);
    //     nftAddresses.push('0x8971718bca2b7fc86649b84601b17b634ecbdf19');
    //     let bytesVal = await bytes.getBytes('0x8971718bca2b7fc86649b84601b17b634ecbdf19', i);
    //     nftInfoTracker.push(bytesVal);
    // }
    // for(let i = 0; i < 500; i++) {
    //     nftIds.push(i);
    //     nftAddresses.push('0xF2Afb1AE1ddB274cc1A1D249658687978A4C5533');
    //     let bytesVal = await bytes.getBytes('0xF2Afb1AE1ddB274cc1A1D249658687978A4C5533', i);
    //     nftInfoTracker.push(bytesVal);
    // }
    // for(let i = 0; i < 500; i++) {
    //     nftIds.push(i);
    //     nftAddresses.push('0x5ed117E6f535B5FD8248bc05AD548fa284aDD19E');
    //     let bytesVal = await bytes.getBytes('0x5ed117E6f535B5FD8248bc05AD548fa284aDD19E', i);
    //     nftInfoTracker.push(bytesVal);
    // }
    // // for(let i = 0; i < 50; i++) {
    // //     nftIds.push(i);
    // //     nftAddresses.push('0x7fd16712668DAa387413236395Fa0EdB141258c0');
    // //     let bytesVal = await bytes.getBytes('0x7fd16712668DAa387413236395Fa0EdB141258c0', i);
    // //     nftInfoTracker.push(bytesVal);
    // // }
    // let leaves = nftInfoTracker.map(addr => keccak256(addr));
    // let merkleTree = new MerkleTree(leaves, keccak256, {sortPairs: true});
    // let address = nftInfoTracker[1003];
    // let hashedAddress = keccak256(address);
    // let proof = merkleTree.getHexProof(hashedAddress);
    // let address1 = nftInfoTracker[1004];
    // let hashedAddress1 = keccak256(address1);
    // let proof1 = merkleTree.getHexProof(hashedAddress1);
    // let rootHash = merkleTree.getRoot().toString('hex');
    // rootHash = ("0x").concat(rootHash);
    // console.log(rootHash);
    // let compressedVals = [];
    // let pairs = [
    //     pair.address
    // ];
    // let indices = [
    //     2
    // ];
    // for(let i = 0; i < pairs.length; i++) {
    //     compressedVals.push((await sudoNft.getCompressedPoolVal(pairs, indices)).toString());
    // }
    // const borrow = await sudoNft.borrow(
    //     maPool.address
    //     , compressedVals // address _sudoPool,
    //     , [proof, proof1]// bytes32[][] calldata _merkleProof, 
    //     , [nftIds[1003], nftIds[1004]] // uint256 _lpTokenId,
    //     , ['6800000000000000', '6800000000000000'] // uint256 _amount
    // );
    // borrow.wait();

    // Pay interest
    // const approveTransfer = await token.approve(sudoNft.address, '700000000000000000000');
    // approveTransfer.wait();
    // const payInterest = await sudoNft.payInterest(
    //     maPool.address // address _lendingContract,
    //     , [6] // uint256[] calldata _epoch,
    // );
    // payInterest.wait();

    // Repay
    // const approveRepay = await token.approve(
    //     sudoNft.address, 
    //     '70000000000000000000'
    // );
    // approveRepay.wait();
    // console.log(await lend.loans(sudoNft.address, 3));
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
    //     , [1] // uint256 _lpTokenId,
    //     , ['31666666666666666'] // uint256[] calldata _epoch
    // );
    // liquidate.wait();

    //Exchange LP for NFT
    // const exchangeLPforNFT = await sudoNft.exchangeLPforNFT(
    //     pair.address,
    //     [877], // NFT id
    //     [10006] // LP token id
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

