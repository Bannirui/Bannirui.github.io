---
title: javac-00-javac源码环境
category_bar: true
categories: javac
date: 2026-09-25 01:43:58
---

javac的源码仅仅是jdk工程的一部分，因此整个配置跟jvm环境搭建一样{%post_link java/jvm-01-在Linux上编译openjdk22%}

唯一的区别就是让vscode能识别java项目，进行javac源码的跳转，只要配置`.vscode/settings.json`就行

下面是完整的vscode配置

```json
{
    // HotSpot代码
    "C_Cpp.default.compileCommands": "${workspaceFolder}/build/linux-x86_64-server-slowdebug/compile_commands.json",
    "C_Cpp.errorSquiggles": "disabled",
    "C_Cpp.default.intelliSenseMode": "linux-gcc-x64",

    // javac代码
    "java.project.sourcePaths": [
        "src/jdk.compiler/share/classes",
        "src/java.compiler/share/classes"
    ],

    "java.autobuild.enabled": false,

    "search.exclude": {
        "**/build/**": true,
        "**/.git/**": true
    },

    "editor.formatOnSave": false,
    "files.maxMemoryForLargeFilesMB": 4096
}
```