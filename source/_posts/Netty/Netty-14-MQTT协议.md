---
title: Netty-14-MQTT协议
category_bar: true
categories: Netty
date: 2026-08-12 22:16:29
---

其实协议本身是什么不重要，主要是为了借助MQTT协议引出经典的面试题

怎么解决粘包的

## 1 什么是粘包

先明确一点，这个跟TCP一点关系都没有，TCP只负责可靠、有序、不重复把数据交给应用层就行。TCP是面向字节流的，所以是应用层可能识别不出来数据边界在哪儿。

所以是应用层要设计自己的方式识别出来自己要的数据边界在哪

## 2 MQTT协议

[直接看官网的文档](https://docs.oasis-open.org/mqtt/mqtt/v5.0/cs01/mqtt-v5.0-cs01.html#)

## 3 MQTT的解码

对照着官网的协议格式

### 3.1 fixed header的解码

```java
    /**
     * 从tcp字节流里面解析出mqtt的fixed_header
     * Bit         7   6   5   4               |     3   |  2   1 |   0
     * byte 1   MQTT Control Packet type       |   DUP   |  QoS   | RETAIN
     * byte 2…                         Remaining Length
     *
     * byte2...是变长编码 最少用1个字节 最多用4个字节
     * 每个字节的高7位是标识是不是变长 要不要继续解析 剩下的低[6...0]这7位才是真正的有效值
     * 因为这两个原因 1是只有4个字节的上限 2是每个字节做多只能用7位 mqtt为了这么点bit能表达更大的length
     * 就采用了128进制
     * 第1个字节表达的长度=第1个字节的低7位有效值*128^0
     * 第2个字节表达的长度=第2个字节的低7位有效值*128^1
     * 第3个字节表达的长度=第2个字节的低7位有效值*128^2
     * 第4个字节表达的长度=第2个字节的低7位有效值*128^3
     *
     * byte1的高4位是mqtt的类型对应的值
     * byte1的低4位按照位有不同的作用
     *      Bits    3  |  2    1  |  0
     *             DUP |   QoS    | RETAIN
     * @param ctx
     * @param buffer 里面是tcp字节流的数据
     * @return fixed_header
     */
    private static MqttFixedHeader decodeFixedHeader(ChannelHandlerContext ctx, ByteBuf buffer) {
        // fixed_header的byte1
        short b1 = buffer.readUnsignedByte();
        // mqtt fixed_header的byte1的高4位 mqtt的类型
        MqttMessageType messageType = MqttMessageType.valueOf(b1 >> 4);
        // byte1的低4位情况
        // 第3位被置位了说明是DUP
        boolean dupFlag = (b1 & 0x08) == 0x08;
        // 第2位和第1位这两位组合起来的值是多少 无非就是0 1 2 3这4种情况
        int qosLevel = (b1 & 0x06) >> 1;
        // 第0位被置位了说明是RETAIN
        boolean retain = (b1 & 0x01) != 0;

        switch (messageType) {
            case PUBLISH:
                if (qosLevel == 3) {
                    throw new DecoderException("Illegal QOS Level in fixed header of PUBLISH message ("
                            + qosLevel + ')');
                }
                break;

            case PUBREL:
            case SUBSCRIBE:
            case UNSUBSCRIBE:
                if (dupFlag) {
                    throw new DecoderException("Illegal BIT 3 in fixed header of " + messageType
                            + " message, must be 0, found 1");
                }
                if (qosLevel != 1) {
                    throw new DecoderException("Illegal QOS Level in fixed header of " + messageType
                            + " message, must be 1, found " + qosLevel);
                }
                if (retain) {
                    throw new DecoderException("Illegal BIT 0 in fixed header of " + messageType
                            + " message, must be 0, found 1");
                }
                break;

            case AUTH:
            case CONNACK:
            case CONNECT:
            case DISCONNECT:
            case PINGREQ:
            case PINGRESP:
            case PUBACK:
            case PUBCOMP:
            case PUBREC:
            case SUBACK:
            case UNSUBACK:
                if (dupFlag) {
                    throw new DecoderException("Illegal BIT 3 in fixed header of " + messageType
                            + " message, must be 0, found 1");
                }
                if (qosLevel != 0) {
                    throw new DecoderException("Illegal BIT 2 or 1 in fixed header of " + messageType
                            + " message, must be 0, found " + qosLevel);
                }
                if (retain) {
                    throw new DecoderException("Illegal BIT 0 in fixed header of " + messageType
                            + " message, must be 0, found 1");
                }
                break;
            default:
                throw new DecoderException("Unknown message type, do not know how to validate fixed header");
        }
        // 解析出来的length结果
        int remainingLength = 0;
        // 解析length的时候第1个字节进制是128的0次方
        int multiplier = 1;
        short digit;
        /**
         * fixed_header里面的byte2编码特点 它不一定刚好仅仅是1个字节 这个字段本身就是变长的 最少1个字节 最多4个字节 怎么知道是不是变长的 在高7位标识
         * 高7位 1表示remain length这个字段需要继续解析后面的字节 0表示这个字段的解析到此为止
         * 低0到低6位 才是真正的长度内容
         * 最多循环看4个字节 看高7位的表示决定要不要继续解析
         */
        int loops = 0;
        // 因为remain length至少占1个字节 所以用do...while 不管什么情况先搞出来1个字节拿出来它的内容 看后再看高7位的标识 决定要不要继续
        do {
            // 先拿出来1个字节
            digit = buffer.readUnsignedByte();
            /**
             * mqtt不是按照10进制存储的 因为最多只能用4个字节表达remain length 而且每个字节只能用7个位
             * 所以mqtt为了28个有效位能表达更大的长度 就用了128进制
             * 第1个字节 n1*128^0
             * 第2个字节 n2*128^1
             * 第3个字节 n3*128^2
             * 第4个字节 n4*128^3
             */
            // 当前这个字节的低7位有效内容拿出来 乘以当前字节的对应的进制
            remainingLength += (digit & 127) * multiplier;
            // 下一个字节的进制在当前进制上成128
            multiplier *= 128;
            loops++;
        } while ((digit & 128) != 0 && loops < 4); // 高7位置1了就继续 上限解析4个字节

        // MQTT protocol limits Remaining Length to 4 bytes
        // 防御性检查 协议规定length这个byte2变成最多4个字节 要是第4个字节的标志位高7位还是1 就说明协议本身就有问题了 不规范
        if (loops == 4 && (digit & 128) != 0) {
            throw new DecoderException("remaining length exceeds 4 digits (" + messageType + ')');
        }
        MqttFixedHeader decodedFixedHeader =
                new MqttFixedHeader(messageType, dupFlag, MqttQoS.valueOf(qosLevel), retain, remainingLength);
        return validateFixedHeader(ctx, resetUnusedFields(decodedFixedHeader));
    }
```

### 3.2 variable header的解码

为什么叫variable，就是因为根据不同的packet type，这个header有没有都不一定，即使有，每个header内容都不一样

我就以CONNECT类型为例

```java
    /**
     * connect类型的variable header包含的字段有
     *   - Protocol Name 字符串 6个字节
     *                   byte1 byte2 byte3 byte4 byte5 byte6
     *                   MSB   LSB    M      Q     T    T
     *   - Protocol Level 1个字节 值是5表示 Version5
     *   - Connect Flags 1个字节 8位分别是
     *                   Bit        7               6              5            4           3         2            1           0
     *                       User Name Flag | Password Flag | Will Retain |        Will QoS     | Will Flag | Clean Start | Reserved
     *   - Keep Alive 2个字节 整数
     *   - Properties
     * 编字符串的时候先给出字符串长度 再给字符串内容 MSB的高8位 LSB是低8位 组合起来就是字符串长度
     */
    private static Result<MqttConnectVariableHeader> decodeConnectionVariableHeader(
            ChannelHandlerContext ctx,
            ByteBuf buffer) {
        // 解析出字符串 字段Protocol Name是固定值MQTT
        final Result<String> protoString = decodeString(buffer);
        // 编码MQTT用了6个字节
        int numberOfBytesConsumed = protoString.numberOfBytesConsumed;
        // 编码Protocol Level用1个字节
        final byte protocolLevel = buffer.readByte();
        numberOfBytesConsumed += 1;

        MqttVersion version = MqttVersion.fromProtocolNameAndLevel(protoString.value, protocolLevel);
        MqttCodecUtil.setMqttVersion(ctx, version);
        // flags占1字节
        final int b1 = buffer.readUnsignedByte();
        numberOfBytesConsumed += 1;
        // 2个字节的整数
        final int keepAlive = decodeMsbLsb(buffer);
        numberOfBytesConsumed += 2;
        // flags的高7位有没有被置位
        final boolean hasUserName = (b1 & 0x80) == 0x80;
        // flags的高6位有没有被置位
        final boolean hasPassword = (b1 & 0x40) == 0x40;
        // flags的高5位有没有被置位
        final boolean willRetain = (b1 & 0x20) == 0x20;
        // 拿出来flags字节的低3和低4位的值
        final int willQos = (b1 & 0x18) >> 3;
        // flags的低2位有没有被置位
        final boolean willFlag = (b1 & 0x04) == 0x04;
        // flags的低1位有没有被置位
        final boolean cleanSession = (b1 & 0x02) == 0x02;
        if (version == MqttVersion.MQTT_3_1_1 || version == MqttVersion.MQTT_5) {
            final boolean zeroReservedFlag = (b1 & 0x01) == 0x0;
            if (!zeroReservedFlag) {
                // MQTT v3.1.1: The Server MUST validate that the reserved flag in the CONNECT Control Packet is
                // set to zero and disconnect the Client if it is not zero.
                // See https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc385349230
                throw new DecoderException("non-zero reserved flag");
            }
        }

        final MqttProperties properties;
        if (version == MqttVersion.MQTT_5) {
            final Result<MqttProperties> propertiesResult = decodeProperties(buffer);
            properties = propertiesResult.value;
            numberOfBytesConsumed += propertiesResult.numberOfBytesConsumed;
        } else {
            properties = MqttProperties.NO_PROPERTIES;
        }

        final MqttConnectVariableHeader mqttConnectVariableHeader = new MqttConnectVariableHeader(
                version.protocolName(),
                version.protocolLevel(),
                hasUserName,
                hasPassword,
                willRetain,
                willQos,
                willFlag,
                cleanSession,
                keepAlive,
                properties);
        return new Result<MqttConnectVariableHeader>(mqttConnectVariableHeader, numberOfBytesConsumed);
    }
```

### 3.3 payload的解码

每个类型的payload也是不一样的，已知payload大小了，直接从buf里面读，按照官网的协议格式解析就行

```java
                // 开始解析payload payload的大小是bytesRemainingInVariablePart
                final Result<?> decodedPayload =
                        decodePayload(
                                ctx,
                                buffer,
                                mqttFixedHeader.messageType(),
                                bytesRemainingInVariablePart,
                                maxClientIdLength,
                                variableHeader);
```

## 4 怎么拆包粘包的

应用层解决这个问题，它不是一个手段，而是一套组合拳

### 4.1 状态机

为什么要状态机，如果现在解析fixed header过程中发现buf里面数据不够，即使我后知后觉发现的时候把数据恢复了，你是不是要标记下次TCP来数据的时候是要继续fixed header的解码

这是一个原因，另一个原因是

TCP过来的给操作系统的是buf，也就是数据流里面又来了一坨数据，os要把这一坨数据给netty，netty用自己的Buf缓存起来了，问题是此时netty是不知道这一整坨数据的情况的

- 可能一个协议都不够
- 可能刚好可以解析成一个协议
- 可能可以解析成1.5个协议 那么剩下来的0.5就要继续缓存在netty里面

因此合理的做法是什么，当os给数据过来了，netty别管三七二十一，直接套一个while(有数据)在自己的Buf上，然后回调给业务层去解码，所以在解码里面最好需要一个状态机，简化了流程的推进

mqtt的协议有fixed header、variable header和payload，对应的状态就是这3个

```java
    /**
     * mqtt协议格式是 fixed header+variable header+payload
     * 数据是源源不断流的方式从tcp过来 不能说解析一般发现数据不够一个协议就丢掉 所以用状态机的方式
     * 意味着下次准备解析数据是从什么样状态开始的
     * 初始的时候肯定从fixed_header开始的
     */
    enum DecoderState {
        READ_FIXED_HEADER,
        READ_VARIABLE_HEADER,
        READ_PAYLOAD,
        BAD_MESSAGE,
    }
```

状态机的使用很简单

```java
    protected void decode(ChannelHandlerContext ctx, ByteBuf buffer, List<Object> out) throws Exception {
        switch (state()) {
            case READ_FIXED_HEADER: try {
                // 开始解析fixed_header
                mqttFixedHeader = decodeFixedHeader(ctx, buffer);
                bytesRemainingInVariablePart = mqttFixedHeader.remainingLength();
                // fixed_header已经解析出来了 保存现在已经读到什么地方了 推进状态机 准备读variable header
                checkpoint(DecoderState.READ_VARIABLE_HEADER);
                // fall through
                // 属于是小设计了 利用switch...case没有break就贯穿的特性 因为mqtt的协议是fixed header/variable header/payload 所以只要解析没问题就继续下去 知道最后要么完整的mqtt被解析出来放到out里面 要么有问题中断了等待decoder的下一个while过来
            } catch (Exception cause) {
                out.add(invalidMessage(cause));
                return;
            }

            case READ_VARIABLE_HEADER:  try {
                // 开始解析variable header
                final Result<?> decodedVariableHeader = decodeVariableHeader(ctx, buffer, mqttFixedHeader);
                variableHeader = decodedVariableHeader.value;
                if (bytesRemainingInVariablePart > maxBytesInMessage) {
                    buffer.skipBytes(actualReadableBytes());
                    throw new TooLongFrameException("too large message: " + bytesRemainingInVariablePart + " bytes");
                }
                // fixed header里面解析到的remain length是包含了fixed header后面的variable header和payload 现在variable header解析出来了知道了在tcp字节流里面variable header占了多少字节
                // 那么剩下来的payload占多少字节
                bytesRemainingInVariablePart -= decodedVariableHeader.numberOfBytesConsumed;
                // variable header已经解析出来了 保存现在已经读到什么地方了 推进状态机 准备读payload
                checkpoint(DecoderState.READ_PAYLOAD);
                // fall through
            } catch (Exception cause) {
                out.add(invalidMessage(cause));
                return;
            }

            case READ_PAYLOAD: try {
                // 开始解析payload payload的大小是bytesRemainingInVariablePart
                final Result<?> decodedPayload =
                        decodePayload(
                                ctx,
                                buffer,
                                mqttFixedHeader.messageType(),
                                bytesRemainingInVariablePart,
                                maxClientIdLength,
                                variableHeader);
                bytesRemainingInVariablePart -= decodedPayload.numberOfBytesConsumed;
                if (bytesRemainingInVariablePart != 0) {
                    throw new DecoderException(
                            "non-zero remaining payload bytes: " +
                                    bytesRemainingInVariablePart + " (" + mqttFixedHeader.messageType() + ')');
                }
                // payload已经解析出来了 保存现在已经读到什么地方了 推进状态机 现在已经解析了一个完整的mqtt协议了 那么下一次要解析的是下一个协议的fixed header
                checkpoint(DecoderState.READ_FIXED_HEADER);
                MqttMessage message = MqttMessageFactory.newMessage(
                        mqttFixedHeader, variableHeader, decodedPayload.value);
                mqttFixedHeader = null;
                variableHeader = null;
                // 一个完整的mqtt协议完整的解析出来了 才放到out里面让netty传给pipeline里面后面的handler
                out.add(message);
                break;
            } catch (Exception cause) {
                out.add(invalidMessage(cause));
                return;
            }

            case BAD_MESSAGE:
                // Keep discarding until disconnection.
                buffer.skipBytes(actualReadableBytes());
                break;

            default:
                // Shouldn't reach here.
                throw new Error();
        }
    }
```

### 4.2 读前检测的Buf

```java
// 从这个名字就看得出来性质 它是带状态回滚的 在解码过程中发现buf里面数据不够的时候是要回滚到这一次解码之前的状态的
public abstract class ReplayingDecoder<S> extends ByteToMessageDecoder {

    static final Signal REPLAY = Signal.valueOf(ReplayingDecoder.class, "REPLAY");

    // 这个Buf是专门给这种带状态回滚的适配的 它把read方法重写了 在read之前都会检查一下buf里面的内容够不够 不够就抛异常
    private final ReplayingDecoderByteBuf replayable = new ReplayingDecoderByteBuf();
```

```java
    /**
     *  buf被2个指针划分成3块
     *    [...read]  [read...write] [write...]
     *   已经被读过的    还没被读的      待写的
     * @param index 现在buf的读指针
     * @param length 希望从buf里面读多少内容
     */
    private void checkIndex(int index, int length) {
        // 说白了就是检查可读区域够不够length个字节内容 不够就抛约定好的异常 调用方就知道这是啥意思了
        if (index + length > buffer.writerIndex()) {
            throw REPLAY;
        }
    }
```

### 4.3 解码时候发现Buf异常就恢复

```java
    @Override
    protected void callDecode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) {
        replayable.setCumulation(in);
        try {
            while (in.isReadable()) {
                // netty累积的字节流[0....readIndex]表示被读过了 一定要记录下来 因为下面在解码的时候可能发生异常 如果因为字节流不够解析出完整的一个协议 是要回滚的 等待TCP继续送数据过来
                int oldReaderIndex = checkpoint = in.readerIndex();
                int outSize = out.size();

                if (outSize > 0) {
                    fireChannelRead(ctx, out, outSize);
                    out.clear();

                    // Check if this handler was removed before continuing with decoding.
                    // If it was removed, it is not safe to continue to operate on the buffer.
                    //
                    // See:
                    // - https://github.com/netty/netty/issues/4635
                    if (ctx.isRemoved()) {
                        break;
                    }
                    outSize = 0;
                }

                S oldState = state;
                int oldInputLength = in.readableBytes();
                try {
                    // 开始真正的解码 这个地方传的第2个参数是ReplayingDecoderByteBuf 它的每个read方法都被重写了 真正读之前会检查一下字节够不够 不够就抛约定的异常让下面catch捕获
                    decodeRemovalReentryProtection(ctx, replayable, out);

                    // Check if this handler was removed before continuing the loop.
                    // If it was removed, it is not safe to continue to operate on the buffer.
                    //
                    // See https://github.com/netty/netty/issues/1664
                    if (ctx.isRemoved()) {
                        break;
                    }

                    if (outSize == out.size()) {
                        if (oldInputLength == in.readableBytes() && oldState == state) {
                            throw new DecoderException(
                                    StringUtil.simpleClassName(getClass()) + ".decode() must consume the inbound " +
                                    "data or change its state if it did not decode anything.");
                        } else {
                            // Previous data has been discarded or caused state transition.
                            // Probably it is reading on.
                            continue;
                        }
                    }
                } catch (Signal replay) {
                    // 解码报错了 并且约定的这个报错是要回滚的情况 比如netty累积的字节流是不够一个完整的协议的 这种情况已经解码出来的数据是不能丢的 只能恢复buf里面的读指针位置 然后等tcp送数据过来
                    // 再次检查一下这个异常确保是约定的回滚
                    replay.expect(REPLAY);

                    // Check if this handler was removed before continuing the loop.
                    // If it was removed, it is not safe to continue to operate on the buffer.
                    //
                    // See https://github.com/netty/netty/issues/1664
                    if (ctx.isRemoved()) {
                        break;
                    }

                    // Return to the checkpoint (or oldPosition) and retry.
                    // 在真正解码之前已经保存了read index 现在decode过程中发现buf中数据不够解码成完整的协议 要恢复 就把buf的read index恢复到解码之前就行
                    int checkpoint = this.checkpoint;
                    if (checkpoint >= 0) {
                        in.readerIndex(checkpoint);
                    } else {
                        // Called by cleanup() - no need to maintain the readerIndex
                        // anymore because the buffer has been released already.
                    }
                    break;
                }

                if (oldReaderIndex == in.readerIndex() && oldState == state) {
                    throw new DecoderException(
                           StringUtil.simpleClassName(getClass()) + ".decode() method must consume the inbound data " +
                           "or change its state if it decoded something.");
                }
                if (isSingleDecode()) {
                    break;
                }
            }
        } catch (DecoderException e) {
            throw e;
        } catch (Exception cause) {
            throw new DecoderException(cause);
        }
    }
```