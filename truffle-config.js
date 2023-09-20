const path = require("path");
require('dotenv').config({path: './.env'});
const HDWalletProvider = require("@truffle/hdwallet-provider");
const AccountIndex = 1;
const sapphire = require('@oasisprotocol/sapphire-paratime');

module.exports = {

  networks: {
    sapphireTest: {
      provider: () =>
      sapphire.wrap(new HDWalletProvider(process.env.MNEMONICTEST, "https://testnet.sapphire.oasis.dev",AccountIndex)),
      network_id: 0x5aff,
    },
    development: {
      port: 8545,
      network_id: "1693562755247",
      host: "127.0.0.1"
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.17",      // Fetch exact version from solc-bin
    }
  }
};
