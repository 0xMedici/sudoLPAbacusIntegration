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

    //Sudo pool connect
    LSSVMPairEnumerableETH = await ethers.getContractFactory("LSSVMPairEnumerableETH");
    pair = await LSSVMPairEnumerableETH.attach("0xC8AF1Bc41943471a4E4EE990f9e3697183BbD956");
    console.log("Pair:", pair.address);

    //Proof checker
    ProofCheck = await ethers.getContractFactory("ProofCheck");
    check = await ProofCheck.attach("0x8Fd6b316FdAA43cA6e6a70d6694cEC37Ca60875d");
    console.log("ProofCheck:", check.address);

    //SudoNFT connect
    SudoNft = await ethers.getContractFactory("SudoNft");
    // sudoNft = await SudoNft.deploy(
    //     deployer.address,
    //     '0xF0202E9267930aE942F0667dC6d805057328F6dC' // sudo factory address
    //     , '0x8971718bca2b7fc86649b84601b17b634ecbdf19' // nft collection address 
    //     , 860 // total token supply
    // );
    sudoNft = await SudoNft.attach('0xc2B84BDfd4F468f77A1826E7ADae1d20e256b833');
    console.log("Sudo NFT:", sudoNft.address);
    
    //Lend connect
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach("0xC599933bD53c6Ba9a28A5C1D7AFEBd278D3AB822");

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
    factory = await Factory.attach("0x7b8C5b8a3bd8D4ea3e19eeC0e20d09DAA77ed3dd");
    Vault = await ethers.getContractFactory("Vault");
    // const initiate = await factory.initiateMultiAssetVault(
    //     "SudoLPTest18"
    // );
    // initiate.wait();
    let vaultAddress = await factory.getPoolAddress("SudoLPTest18");
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
    // console.log(await lend.loans(sudoNft.address, 9));
    // console.log(await sudoNft.pairing(pair.address));
    console.log(await erc721.ownerOf(111));
    // console.log(await sudoNft.ownerOf(9));

    // ------- EXECUTE FUNCTIONS -------- //

    // Include NFTs in pool
    // let nftIds = new Array();
    // let nftAddresses = new Array();
    // let nftInfoTracker = [];
    // for(let i = 0; i < 861; i++) {
    //     nftIds.push(i+1);
    //     nftAddresses.push(erc721.address);
    //     let bytesVal = await bytes.getBytes(erc721.address, i + 1);
    //     nftInfoTracker.push(bytesVal);
    // }
    // for(let i = 0; i < 861; i++) {
    //     nftIds.push(i+1);
    //     nftAddresses.push(sudoNft.address);
    //     let bytesVal = await bytes.getBytes(sudoNft.address, i + 1);
    //     nftInfoTracker.push(bytesVal);
    // }
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
    // const begin = await maPool.begin(3, 100, 100, 360, token.address, 100, 10);
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
    //     currentEpoch + 3,
    // );
    // purchase.wait();
    // console.log("Purchase succesful");

    // Remove liquidity 
    // const sell = await maPool.sell(2);
    // sell.wait();
    
    // Initiate transfer 
    // const initiateSudoTransfer = await sudoNft.initiatePool(pair.address);
    // initiateSudoTransfer.wait();
    // console.log("Pool transfer initiated!");

    // Transfer ownership from
    // const transferOwnership = await pair.transferOwnership(
    //     sudoNft.address
    // );
    // transferOwnership.wait();
    // console.log("Ownership transferred!");

    // Transfer ownership to
    // const callTransferOwnership = await sudoNft.callTransferOwnership(
    //     pair.address,
    // );
    // callTransferOwnership.wait();

    //Deposit NFTs
    // console.log(await erc721.ownerOf(111));
    // const transferNFT = await erc721.transferFrom(deployer.address, pair.address, 111);
    // transferNFT.wait();
    // console.log("NFT transferred!");

    // Borrow
    // let nftIds = new Array();
    // let nftAddresses = new Array();
    // let nftInfoTracker = [];
    // for(let i = 0; i < 861; i++) {
    //     nftIds.push(i+1);
    //     nftAddresses.push(erc721.address);
    //     let bytesVal = await bytes.getBytes(erc721.address, i + 1);
    //     nftInfoTracker.push(bytesVal);
    // }
    // for(let i = 0; i < 861; i++) {
    //     nftIds.push(i+1);
    //     nftAddresses.push(sudoNft.address);
    //     let bytesVal = await bytes.getBytes(sudoNft.address, i + 1);
    //     nftInfoTracker.push(bytesVal);
    // }
    // console.log("ADDRESS", nftAddresses[869]);
    // console.log("ID:", nftIds[869]);
    // let leaves = nftInfoTracker.map(addr => keccak256(addr));
    // let merkleTree = new MerkleTree(leaves, keccak256, {sortPairs: true});
    // let address = nftInfoTracker[869];
    // let hashedAddress = keccak256(address);
    // let proof = merkleTree.getHexProof(hashedAddress);
    // let rootHash = merkleTree.getRoot().toString('hex');
    // rootHash = ("0x").concat(rootHash);
    // let v1 = merkleTree.verify(proof, hashedAddress, rootHash);
    // console.log("PROOF OUTCOME:", v1);
    // console.log(await check.proofCheck(proof, rootHash, sudoNft.address, 9));
    // let outcome = await maPool.getHeldTokenExistence(proof, sudoNft.address, 9);
    // console.log(outcome);
    // console.log("Proof created");
    // const borrow = await sudoNft.borrow(
    //     lend.address// address _lendingContract,
    //     , proof// bytes32[] calldata _merkleProof, 
    //     , maPool.address // address _spotPool,
    //     , pair.address // address _sudoPool,
    //     , 9 // uint256 _lpTokenId,
    //     , '70000000000000000' // uint256 _amount
    // );
    // borrow.wait();

    // Pay interest
    // console.log(await lend.getInterestPayment(
    //     [1, 2],
    //     sudoNft.address,
    //     9
    // ));
    // const approveTransfer = await token.approve(sudoNft.address, await lend.getInterestPayment(
    //     [1, 2],
    //     sudoNft.address,
    //     9
    // ));
    // approveTransfer.wait();
    // const payInterest = await sudoNft.payInterest(
    //     lend.address // address _lendingContract,
    //     , [2]  // uint256[] calldata _epoch,
    //     , 9 // uint256 _lpTokenId
    // );
    // payInterest.wait();

    // Repay
    // console.log(
    //     (await lend.getInterestPayment(
    //         [0], 
    //         sudoNft.address, 
    //         8
    //     )).toString()
    // );
    // const approveRepay = await token.approve(
    //     sudoNft.address, 
    //     '70000000000000000000'
    // );
    // approveRepay.wait();
    // const repay = await sudoNft.repay(
    //     lend.address // address _lendingContract,
    //     , pair.address // address _sudoPool,
    //     , 9 // uint256 _lpTokenId,
    //     , (parseInt(await lend.getInterestPayment([3], sudoNft.address, 9)) + parseInt('70000000000000000')).toString()// uint256 _amount
    // );
    // repay.wait();

    // Liquidate
    // const approveTransfer = await token.approve(sudoNft.address, '7000000000000000000');
    // approveTransfer.wait();
    // const liquidate = await sudoNft.liquidateLp(
    //     lend.address // address _lendingContract,
    //     , 9 // uint256 _lpTokenId,
    //     , [0, 1, 2, 3] // uint256[] calldata _epoch
    // );
    // liquidate.wait();

    //Exchange LP for NFT
    // const exchangeLPforNFT = await sudoNft.exchangeLPforNFT(
    //     [111], // NFT id
    //     9 // LP token id
    // );
    // exchangeLPforNFT.wait();
    // console.log("LP has been exchange for NFT!");

    //Exchange LP for ETH
    // const exchangeLPforETH = await sudoNft.exchangeLPforETH(
    //     9
    // );
    // exchangeLPforETH.wait();
    // console.log("LP has been exchanged for ETH!");

    //Purchase in Sudo pool
    // let price = await pair.getBuyNFTQuote(1);
    // const purchaseNft = await pair.swapTokenForSpecificNFTs(
    //     [111]
    //     , (price[3]).toString()
    //     , deployer.address
    //     , false
    //     , constants.AddressZero
    //     , { value: (price[3]).toString() }
    // );
    // purchaseNft.wait();
    // console.log("NFT purchased!");

    //Sell to Sudo pool
    // const approveNftTransfer = await erc721.approve(pair.address, 111);
    // approveNftTransfer.wait();
    // let salePrice = await pair.getSellNFTQuote(1);
    // console.log(salePrice[3]);
    // const sellNft = await pair.swapNFTsForToken(
    //     [111]
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

