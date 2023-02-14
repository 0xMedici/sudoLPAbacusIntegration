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
    rinkeby: {
      url: 'https://rinkeby.infura.io/v3/b2d15a1424b74f158a3ccf9f78f2e8e0',
      accounts: ["0ae57621ed6615bcb420d1ae1ee75d4ba0b4f3d6eca40514d8c52885152eb861"],
    },
    ropsten: {
      url: 'https://ropsten.infura.io/v3/b2d15a1424b74f158a3ccf9f78f2e8e0',
      accounts: ["0ae57621ed6615bcb420d1ae1ee75d4ba0b4f3d6eca40514d8c52885152eb861"],
    },
    goerli: {
      url: 'https://goerli.infura.io/v3/b2d15a1424b74f158a3ccf9f78f2e8e0',
      accounts: ["0ae57621ed6615bcb420d1ae1ee75d4ba0b4f3d6eca40514d8c52885152eb861"],
    }
  },
  etherscan: {
    apiKey: "B31UJHH3YQKG7B2MIEKMRWV61E4BQE7KCG"
  }
};
