# libFuzzer Tutorial

* Login into your [GCE](https://cloud.google.com/compute/) account or create one.
* Create a new VM and ssh to it
   * Ubuntu 14.04 LTS is recommended, other VMs may or may not work
   * Choose as many CPUs as you can
   * Choose "Access scopes" = "Allow full access to all Cloud APIs"
* Set up the VM: 
```
 sudo apt-get --yes install git 
 git clone https://github.com/google/fuzzer-test-suite.git FTS
 ./FTS/tutorial/install-deps.sh
 ./FTS/tutorial/install-clang.sh
 svn co http://llvm.org/svn/llvm-project/llvm/trunk/lib/Fuzzer
 ```
