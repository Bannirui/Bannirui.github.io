---
title: JNI使用
date: 2023-05-14 10:44:19
tags: [ JNI ]
categories: [ 工具 ]
---

### 1 项目结构

在maven项目中新建2个模块

* jni
* native

```xml
- parent
  - jni
  - native
```

#### 1.1 parent pom

```xml
<modules>        
    <module>native</module>
    <module>jni</module>
</modules>
```

#### 1.2 jni pom

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>com.github.bannirui</groupId>
        <artifactId>parent</artifactId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>jni</artifactId>
    <packaging>jar</packaging>

    <dependencies>
        <dependency>
            <groupId>com.github.fommil</groupId>
            <artifactId>jniloader</artifactId>
            <version>1.1</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <artifactId>maven-compiler-plugin</artifactId>
            </plugin>

            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>2.7</version>
                <configuration>
                    <systemPropertyVariables>
                        <java.library.path>${project.build.directory}/classes</java.library.path>
                    </systemPropertyVariables>
                </configuration>
            </plugin>

            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-dependency-plugin</artifactId>
                <version>2.10</version>
                <executions>
                    <execution>
                        <id>copy</id>
                        <phase>compile</phase>
                        <goals>
                            <goal>copy</goal>
                        </goals>
                        <configuration>
                            <artifactItems>
                                <artifactItem>
                                    <groupId>com.zto.ts</groupId>
                                    <artifactId>native</artifactId>
                                    <version>1.0-SNAPSHOT</version>
                                    <type>so</type>
                                    <overWrite>true</overWrite>
                                    <outputDirectory>${project.build.directory}/classes</outputDirectory>
                                    <destFileName>libdistance.so</destFileName>
                                </artifactItem>
                            </artifactItems>
                        </configuration>
                    </execution>
                </executions>
            </plugin>

            <plugin>
                <artifactId>maven-assembly-plugin</artifactId>
                <configuration>
                    <descriptorRefs>
                        <descriptorRef>jar-with-dependencies</descriptorRef>
                    </descriptorRefs>
                </configuration>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>single</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
```

#### 1.3 native pom

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>com.github.bannirui</groupId>
        <artifactId>parent</artifactId>
        <version>1.0-SNAPSHOT</version>
    </parent>

    <artifactId>native</artifactId>
    <packaging>so</packaging>

    <build>
        <plugins>
            <plugin>
                <artifactId>maven-compiler-plugin</artifactId>
            </plugin>

            <plugin>
                <groupId>org.codehaus.mojo</groupId>
                <artifactId>native-maven-plugin</artifactId>
                <version>1.0-alpha-8</version>
                <extensions>true</extensions>
                <configuration>
                    <compilerProvider>generic-classic</compilerProvider>
                    <compilerExecutable>gcc</compilerExecutable>
                    <linkerExecutable>gcc</linkerExecutable>
                    <sources>
                        <source>
                            <directory>${basedir}/src/main/c/jni</directory>
                            <fileNames>
                                <fileName>com_zto_route_scheme_Distance.c</fileName>
                            </fileNames>
                        </source>
                    </sources>
                    <compilerStartOptions>
                        <compilerStartOption>-I ${JAVA_HOME}/include/</compilerStartOption>
                        <compilerStartOption>-I ${JAVA_HOME}/include/linux/</compilerStartOption>
                        <compilerStartOption>-I ${JAVA_HOME}/include/darwin/</compilerStartOption>
                    </compilerStartOptions>
                    <compilerEndOptions>
                        <compilerEndOption>-shared</compilerEndOption>
                        <compilerEndOption>-fPIC</compilerEndOption>
                    </compilerEndOptions>
                    <linkerStartOptions>
                        <linkerStartOption>-I ${JAVA_HOME}/include/</linkerStartOption>
                        <linkerStartOption>-I ${JAVA_HOME}/include/linux/</linkerStartOption>
                        <linkerStartOption>-I ${JAVA_HOME}/include/darwin/</linkerStartOption>
                    </linkerStartOptions>
                    <linkerEndOptions>
                        <linkerEndOption>-shared</linkerEndOption>
                        <linkerEndOption>-fPIC</linkerEndOption>
                    </linkerEndOptions>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

### 2 header文件生成

#### 2.1 定义Java native方法

```xml
- jni
  - src
    - main
      - java
        - com.github.bannirui
          - A.java
```

#### 2.2 声明native方法原型

```java
private static native double a(double d1, double d2, double d3, double d4);
```

#### 2.3 在A.java同级目录下编译为字节码class文件

```shell
jni/src/main.java/com/github/bannirui/> javac A.java
```

#### 2.4 在包路径前执行javah

```shell
jni/src/main/java/> javah A
```

### 3 实现

#### 3.1 将.h文件拷贝到native

```xml
- native
  - src
    - main
      - c
        - jni
          - com_github_bannirui_A.h
```

#### 3.2 .c文件定义实现

```xml
- native
  - src
    - main
      - c
        - jni
          - com_github_bannirui_A.h
          - com_github_bannirui_A.c
```

### 4 maven插件打包

#### 4.1 先将native单独install或deploy

* 如果仅仅是在本地执行或者目的是终将项目打包成jar包，那么install到maven的本地repo就行
* 如果将来是要在公司的远程运维环境进行打包，那么就deply到私服

#### 4.2 parent group的package

对整个项目进行package，最终打包成jar包
