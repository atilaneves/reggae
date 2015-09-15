module reggae.rules.c_and_cpp;

import reggae.rules.common;


@safe:


string unityFileContents(in string projectPath, in string[] files) pure {
    throw new Exception("Cannot perform a unity build with no files");
}
