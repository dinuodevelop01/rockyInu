const RockyInu = artifacts.require('RockyInu');

module.exports = async function (deployer, network, addresses) {
  if(network === 'ethTestnet') {
    // tk
    await deployer.deploy(RockyInu);
  }
  else if(network === 'bscTestnet') {
    await deployer.deploy(RockyInu);
  }
  else {
    await deployer.deploy(RockyInu);
  }
};
