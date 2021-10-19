const main = async () => {
    const nftContractFactory = await hre.ethers.getContractFactory('Puzzle');
    const nftContract = await nftContractFactory.deploy('ipfs://Qmc2cjnm3xdyPoY4X82uLUrfeb6KdabxKTvoKHRcrGRRR9/');
    await nftContract.deployed();
    console.log("Contract deployed to:", nftContract.address);
  };
  
  const runMain = async () => {
    try {
      await main();
      process.exit(0);
    } catch (error) {
      console.log(error);
      process.exit(1);
    }
  };
  
  runMain();