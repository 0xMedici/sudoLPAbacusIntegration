require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
// require("hardhat-gas-reporter");
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 50
      }
    }
  },
  networks: {
    goerli: {
      url: 'https://goerli.infura.io/v3/748d68aab8c141dc8594e2580264e552',
      accounts: ["0ae57621ed6615bcb420d1ae1ee75d4ba0b4f3d6eca40514d8c52885152eb861"],
    }
  },
  etherscan: {
    apiKey: "B31UJHH3YQKG7B2MIEKMRWV61E4BQE7KCG"
  }
};
