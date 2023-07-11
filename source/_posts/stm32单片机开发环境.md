---
title: stm32单片机开发环境
index_img: /img/stm32单片机开发环境.png
date: 2023-04-22 08:35:03
tags: [ STM32 ]
categories: [ 单片机 ]
---
### 1 环境

| Name              | Version   | Mark              | Download\Install                                             |
| ----------------- | --------- | ----------------- | ------------------------------------------------------------ |
| macOS             | 11.5.2    | -                 | -                                                            |
| Clion             | 2023.1.4  | -                 | -                                                            |
| STM32CubeMX       | 6.8.1     | 创建初始化stm工程 | https://www.st.com/en/development-tools/stm32cubemx.html#get-software |
| arm-none-eabi-gcc | 12.2.Rel1 | 交叉编译          | https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads |
| open-ocd          | 0.12.0    | 烧录器            | brew install open-ocd                                        |

### 2 STM32CubeMX安装

#### 2.1 下载

![](stm32单片机开发环境/image-20230710131220187.png)

#### 2.2 安装引导

上述下载的压缩文件zip解压后运行

![](stm32单片机开发环境/image-20230710131511223.png)

![](stm32单片机开发环境/image-20230710132212207.png)

#### 2.3 包管理路径

![](stm32单片机开发环境/image-20230710133319180.png)

### 3 Clion设置

#### 3.1 toolChain

![](stm32单片机开发环境/image-20230422090213150.png)

#### 3.2 cmake

![](stm32单片机开发环境/image-20230422090321312.png)

#### 3.3 openocd && cubemx

![](stm32单片机开发环境/image-20230422090453974.png)

### 4 新建项目

#### 4.1 clion创建项目

![](stm32单片机开发环境/image-20230422090737120.png)



创建项目的过程就是Clion通过上面配置的STM32CubeMX进行初始化，创建好后弹出让我们选择板型配置文件的弹窗，这个文件是后面用来烧录程序用的，也就是openocd要识别的配置文件，现在可以选择跳过，后面到了烧录步骤再单独配置。

![](stm32单片机开发环境/image-20230422090908345.png)

#### 4.2 配置MCU

##### 4.2.1 cube打开项目

![](stm32单片机开发环境/image-20230422091401969.png)



找到刚才通过clion创建的项目。

![](stm32单片机开发环境/image-20230422091453097.png)

##### 4.2.2 mcu型号

生成的默认的项目的stm芯片型号不一定刚好就是自己需要的，比如在下手里只有一个STM32F103C8T6的最小电路，那么我们就更改成自己需要的型号。

![](stm32单片机开发环境/image-20230422091808074.png)



![](stm32单片机开发环境/image-20230422092040516.png)

##### 4.3.3 SYS设置

我买的板子，附带了一个stlink下载器，到时候烧录程序就是通过openocd+usb stlink。

仿真模式选择SWD，只占用2个IO口。

![](stm32单片机开发环境/image-20230422092440068.png)

##### 4.3.4 RCC时钟设置

高速时钟和低速时钟都设置为外部晶振

![](stm32单片机开发环境/image-20230422092609870.png)

##### 4.3.5 时钟树设置

![](stm32单片机开发环境/image-20230710134211727.png)

由电路原理图可知，该开发板使用的外部晶振频率是8MHZ

![](stm32单片机开发环境/image-20230710134507108.png)

##### 4.3.6 管脚设置

###### 4.3.6.1 led电路原理图

LED阳极是3.3V电压，阴极接的是PC13网络标号的管脚。

那么给PC13高电平，LED就灭，给PC13低电平，LED就亮。

![](stm32单片机开发环境/image-20230422093250573.png)

###### 4.3.6.2 PC13管脚设置

将PC13设置为输出

![](stm32单片机开发环境/image-20230422092900128.png)

![](stm32单片机开发环境/image-20230710135333902.png)

#### 4.3 项目配置

* 首先，注意项目路径及项目名，要跟clion创建好的相同，我们的目的是为了将配置好的项目信息覆盖到原有的项目上。
* 其次，开发工具下拉选项没有Clion，因此我就随便选了一个STM32CubeIDE。

![](stm32单片机开发环境/image-20230422093801332.png)

![](stm32单片机开发环境/image-20230710141116467.png)

#### 4.4 保存项目配置

![](stm32单片机开发环境/image-20230422094017500.png)

![](stm32单片机开发环境/image-20230422094107216.png)

### 5 项目开发

#### 5.1 cmake配置

![](stm32单片机开发环境/image-20230422094510651.png)

#### 5.2 编译

![](stm32单片机开发环境/image-20230422094629035.png)

#### 5.3 openocd

##### 5.3.1 配置文件

```shell
set CPUTAPID 0
source [find interface/stlink.cfg]
transport select hla_swd
source [find target/stm32f1x.cfg]
adapter speed 10000
reset_config none
```

![](stm32单片机开发环境/image-20230711093405031.png)

##### 5.3.2 配置项

![](stm32单片机开发环境/image-20230422095001298.png)

![](stm32单片机开发环境/image-20230422095058016.png)

![](stm32单片机开发环境/image-20230422100503658.png)

#### 5.4 code

![](stm32单片机开发环境/image-20230422095443839.png)

上面4.3.6设置GPIO的时候给PC13设置过网络标号，这个地方也可以使用网络标号

```c
HAL_GPIO_WritePin(D2_GPIO_Port, D2_Pin, GPIO_PIN_SET);
HAL_Delay(500);
HAL_GPIO_WritePin(D2_GPIO_Port, D2_Pin, GPIO_PIN_RESET);
HAL_Delay(500);
```

#### 5.5 仿真器接线

![](stm32单片机开发环境/image-20230711094916664.png)

板子是最小系统，只支持SWD接口。

仿真器是ST-Link，支持SWD和TTL两种模式。

在仿真器上有防呆标识，不要连错串口。

#### 5.6 烧录

##### 5.6.1 烧录程序

![](stm32单片机开发环境/image-20230422100203760.png)

##### 5.6.2 观察开发板led闪烁情况

![](stm32单片机开发环境/image-20230711094006084.png)
