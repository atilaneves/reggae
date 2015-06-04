module reggae.rules.compiler_rules;


import reggae.build;
import reggae.config;
import reggae.dependencies;
import reggae.types;
import reggae.sorting;
import std.path : baseName, absolutePath, dirSeparator;
import std.algorithm: map, splitter, remove, canFind, startsWith, find;
import std.array: array, replace;
import std.range: chain;
