module tests.dub_call;


import unit_threaded;
import reggae.dub_call;


immutable reggaeOutput = `Package std_data_json can be upgraded from 0.12.0 to 0.14.0.
Use "dub upgrade" to perform those changes.
WARNING: A deprecated branch based version specification is used for the dependency unit-threaded. Please use numbered versions instead. Also note that you can still use the dub.selections.json file to override a certain dependency to use a branch instead.
Available configurations:
  executable [default]
  unittest

`;

immutable dubOutput = `Package memutils can be upgraded from 0.3.2 to 0.3.6.
Use "dub upgrade" to perform those changes.
Available configurations:
  application [default]
  library
  library-nonet

Generating using build
`;

immutable noConfigOutput = `Available configurations:

Error executing command build:
`;

void testGetConfigs() {

    getConfigurations(reggaeOutput).shouldEqual(DubConfigurations(["executable", "unittest"],
                                                                  "executable"));
    getConfigurations(dubOutput).shouldEqual(DubConfigurations(["application", "library", "library-nonet"],
                                                               "application"));
    DubConfigurations emptyConfigs;
    getConfigurations(noConfigOutput).shouldEqual(emptyConfigs);
}
