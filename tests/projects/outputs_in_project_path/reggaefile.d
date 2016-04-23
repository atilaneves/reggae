module outputs_in_project_path.reggaefile;

import reggae;
enum copy = Target(`$project/generated/release/64/linux/copy.txt`, `cp $in $out`, [Target(`lorem.txt`)]);
mixin build!copy;
