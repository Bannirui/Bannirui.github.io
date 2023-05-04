---
title: JVM-0x06-JVM启动参数
date: 2023-05-04 15:38:32
tags:  [ JVM@15 ]
categories: [ JVM ]
---

JVM启动的前置准备，JVM启动需要的参数。

```c
/**
 * 从jdk入口main函数的启动参数以及解析出来的jre路径 解析出启动JVM的参数
 * @param pargc 1
 *              main函数启动参数有2个
 *                - /jdk/build/macosx-x86_64-server-slowdebug/jdk/bin/java
 *                - VMLoaderTest
 *              第2个VMLoaderTest是用来告知JVM启动后要解析的class字节码文件
 * @param pargv VMLoaderTest
 * @param pmode 解析结果 JVM启动方式
 *                        - 1 Class启动
 *                        - 2 Jar启动
 * @param pwhat 解析结果 JVM启动入口
 *                        - VMLoaderTest 这个类的class字节码文件
 * @param pret 解析结果 JVM退出方式
 *                       - 0 正常退出
 * @param jrepath jre路径 /jdk/build/macosx-x86_64-server-slowdebug/jdk/bin/java
 * @return
 */
static jboolean
ParseArguments(int *pargc, char ***pargv,
               int *pmode, char **pwhat,
               int *pret, const char *jrepath)
{
    int argc = *pargc;
    char **argv = *pargv;
    int mode = LM_UNKNOWN;
    char *arg;

    *pret = 0;

    while ((arg = *argv) != 0 && *arg == '-') {
        char *option = NULL;
        char *value = NULL;
        int kind = GetOpt(&argc, &argv, &option, &value);
        jboolean has_arg = value != NULL && JLI_StrLen(value) > 0;
        jboolean has_arg_any_len = value != NULL;

/*
 * Option to set main entry point
 */
        if (JLI_StrCmp(arg, "-jar") == 0) {
            ARG_CHECK(argc, ARG_ERROR2, arg);
            mode = checkMode(mode, LM_JAR, arg);
        } else if (JLI_StrCmp(arg, "--module") == 0 ||
                   JLI_StrCCmp(arg, "--module=") == 0 ||
                   JLI_StrCmp(arg, "-m") == 0) {
            REPORT_ERROR (has_arg, ARG_ERROR5, arg);
            SetMainModule(value);
            mode = checkMode(mode, LM_MODULE, arg);
            if (has_arg) {
               *pwhat = value;
                break;
            }
        } else if (JLI_StrCmp(arg, "--source") == 0 ||
                   JLI_StrCCmp(arg, "--source=") == 0) {
            REPORT_ERROR (has_arg, ARG_ERROR13, arg);
            mode = LM_SOURCE;
            if (has_arg) {
                const char *prop = "-Djdk.internal.javac.source=";
                size_t size = JLI_StrLen(prop) + JLI_StrLen(value) + 1;
                char *propValue = (char *)JLI_MemAlloc(size);
                JLI_Snprintf(propValue, size, "%s%s", prop, value);
                AddOption(propValue, NULL);
            }
        } else if (JLI_StrCmp(arg, "--class-path") == 0 ||
                   JLI_StrCCmp(arg, "--class-path=") == 0 ||
                   JLI_StrCmp(arg, "-classpath") == 0 ||
                   JLI_StrCmp(arg, "-cp") == 0) {
            REPORT_ERROR (has_arg_any_len, ARG_ERROR1, arg);
            SetClassPath(value);
            if (mode != LM_SOURCE) {
                mode = LM_CLASS;
            }
        } else if (JLI_StrCmp(arg, "--list-modules") == 0) {
            listModules = JNI_TRUE;
        } else if (JLI_StrCmp(arg, "--show-resolved-modules") == 0) {
            showResolvedModules = JNI_TRUE;
        } else if (JLI_StrCmp(arg, "--validate-modules") == 0) {
            AddOption("-Djdk.module.validation=true", NULL);
            validateModules = JNI_TRUE;
        } else if (JLI_StrCmp(arg, "--describe-module") == 0 ||
                   JLI_StrCCmp(arg, "--describe-module=") == 0 ||
                   JLI_StrCmp(arg, "-d") == 0) {
            REPORT_ERROR (has_arg_any_len, ARG_ERROR12, arg);
            describeModule = value;
/*
 * Parse white-space options
 */
        } else if (has_arg) {
            if (kind == VM_LONG_OPTION) {
                AddOption(option, NULL);
            } else if (kind == VM_LONG_OPTION_WITH_ARGUMENT) {
                AddLongFormOption(option, value);
            }
/*
 * Error missing argument
 */
        } else if (!has_arg && (JLI_StrCmp(arg, "--module-path") == 0 ||
                                JLI_StrCmp(arg, "-p") == 0 ||
                                JLI_StrCmp(arg, "--upgrade-module-path") == 0)) {
            REPORT_ERROR (has_arg, ARG_ERROR4, arg);

        } else if (!has_arg && (IsModuleOption(arg) || IsLongFormModuleOption(arg))) {
            REPORT_ERROR (has_arg, ARG_ERROR6, arg);
/*
 * The following cases will cause the argument parsing to stop
 */
        } else if (JLI_StrCmp(arg, "-help") == 0 ||
                   JLI_StrCmp(arg, "-h") == 0 ||
                   JLI_StrCmp(arg, "-?") == 0) {
            printUsage = JNI_TRUE;
            return JNI_TRUE;
        } else if (JLI_StrCmp(arg, "--help") == 0) {
            printUsage = JNI_TRUE;
            printTo = USE_STDOUT;
            return JNI_TRUE;
        } else if (JLI_StrCmp(arg, "-version") == 0) {
            printVersion = JNI_TRUE;
            return JNI_TRUE;
        } else if (JLI_StrCmp(arg, "--version") == 0) {
            printVersion = JNI_TRUE;
            printTo = USE_STDOUT;
            return JNI_TRUE;
        } else if (JLI_StrCmp(arg, "-showversion") == 0) {
            showVersion = JNI_TRUE;
        } else if (JLI_StrCmp(arg, "--show-version") == 0) {
            showVersion = JNI_TRUE;
            printTo = USE_STDOUT;
        } else if (JLI_StrCmp(arg, "--dry-run") == 0) {
            dryRun = JNI_TRUE;
        } else if (JLI_StrCmp(arg, "-X") == 0) {
            printXUsage = JNI_TRUE;
            return JNI_TRUE;
        } else if (JLI_StrCmp(arg, "--help-extra") == 0) {
            printXUsage = JNI_TRUE;
            printTo = USE_STDOUT;
            return JNI_TRUE;
/*
 * The following case checks for -XshowSettings OR -XshowSetting:SUBOPT.
 * In the latter case, any SUBOPT value not recognized will default to "all"
 */
        } else if (JLI_StrCmp(arg, "-XshowSettings") == 0 ||
                   JLI_StrCCmp(arg, "-XshowSettings:") == 0) {
            showSettings = arg;
        } else if (JLI_StrCmp(arg, "-Xdiag") == 0) {
            AddOption("-Dsun.java.launcher.diag=true", NULL);
        } else if (JLI_StrCmp(arg, "--show-module-resolution") == 0) {
            AddOption("-Djdk.module.showModuleResolution=true", NULL);
/*
 * The following case provide backward compatibility with old-style
 * command line options.
 */
        } else if (JLI_StrCmp(arg, "-fullversion") == 0) {
            JLI_ReportMessage("%s full version \"%s\"", _launcher_name, GetFullVersion());
            return JNI_FALSE;
        } else if (JLI_StrCmp(arg, "--full-version") == 0) {
            JLI_ShowMessage("%s %s", _launcher_name, GetFullVersion());
            return JNI_FALSE;
        } else if (JLI_StrCmp(arg, "-verbosegc") == 0) {
            AddOption("-verbose:gc", NULL);
        } else if (JLI_StrCmp(arg, "-t") == 0) {
            AddOption("-Xt", NULL);
        } else if (JLI_StrCmp(arg, "-tm") == 0) {
            AddOption("-Xtm", NULL);
        } else if (JLI_StrCmp(arg, "-debug") == 0) {
            AddOption("-Xdebug", NULL);
        } else if (JLI_StrCmp(arg, "-noclassgc") == 0) {
            AddOption("-Xnoclassgc", NULL);
        } else if (JLI_StrCmp(arg, "-Xfuture") == 0) {
            JLI_ReportErrorMessage(ARG_DEPRECATED, "-Xfuture");
            AddOption("-Xverify:all", NULL);
        } else if (JLI_StrCmp(arg, "-verify") == 0) {
            AddOption("-Xverify:all", NULL);
        } else if (JLI_StrCmp(arg, "-verifyremote") == 0) {
            AddOption("-Xverify:remote", NULL);
        } else if (JLI_StrCmp(arg, "-noverify") == 0) {
            /*
             * Note that no 'deprecated' message is needed here because the VM
             * issues 'deprecated' messages for -noverify and -Xverify:none.
             */
            AddOption("-Xverify:none", NULL);
        } else if (JLI_StrCCmp(arg, "-ss") == 0 ||
                   JLI_StrCCmp(arg, "-oss") == 0 ||
                   JLI_StrCCmp(arg, "-ms") == 0 ||
                   JLI_StrCCmp(arg, "-mx") == 0) {
            char *tmp = JLI_MemAlloc(JLI_StrLen(arg) + 6);
            sprintf(tmp, "-X%s", arg + 1); /* skip '-' */
            AddOption(tmp, NULL);
        } else if (JLI_StrCmp(arg, "-checksource") == 0 ||
                   JLI_StrCmp(arg, "-cs") == 0 ||
                   JLI_StrCmp(arg, "-noasyncgc") == 0) {
            /* No longer supported */
            JLI_ReportErrorMessage(ARG_WARN, arg);
        } else if (JLI_StrCCmp(arg, "-splash:") == 0) {
            ; /* Ignore machine independent options already handled */
        } else if (ProcessPlatformOption(arg)) {
            ; /* Processing of platform dependent options */
        } else {
            /* java.class.path set on the command line */
            if (JLI_StrCCmp(arg, "-Djava.class.path=") == 0) {
                _have_classpath = JNI_TRUE;
            }
            AddOption(arg, NULL);
        }
    }

    if (*pwhat == NULL && --argc >= 0) {
        *pwhat = *argv++;
    }

    if (*pwhat == NULL) {
        /* LM_UNKNOWN okay for options that exit */
        if (!listModules && !describeModule && !validateModules) {
            *pret = 1;
        }
    } else if (mode == LM_UNKNOWN) {
        /* default to LM_CLASS if -m, -jar and -cp options are
         * not specified */
        if (!_have_classpath) {
            SetClassPath(".");
        }
        mode = IsSourceFile(arg) ? LM_SOURCE : LM_CLASS;
    } else if (mode == LM_CLASS && IsSourceFile(arg)) {
        /* override LM_CLASS mode if given a source file */
        mode = LM_SOURCE;
    }

    if (mode == LM_SOURCE) {
        AddOption("--add-modules=ALL-DEFAULT", NULL);
        *pwhat = SOURCE_LAUNCHER_MAIN_ENTRY;
        // adjust (argc, argv) so that the name of the source file
        // is included in the args passed to the source launcher
        // main entry class
        *pargc = argc + 1;
        *pargv = argv - 1;
    } else {
        if (argc >= 0) {
            *pargc = argc;
            *pargv = argv;
        }
    }

    *pmode = mode;

    return JNI_TRUE;
}
```

