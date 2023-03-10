---
title: Java源码-Thread
date: 2023-03-10 23:40:12
tags:
- Java@15
categories:
- Java源码
---

## 1 Demo

```java
public class ThreadTest00 {

    public static void main(String[] args) {
        Thread t0 = new Thread(() -> System.out.println("biz thread..."), "t0"); // 仅设置了一些参数 没有开辟创建线程的资源
        t0.start(); // 创建线程 回调run实现
    }
}
```

## 2 Thread构造方法

```java
// Thread.java
private static native void registerNatives(); // 本地方法 通过JNI方式调用 但是提供的声明做了一个转换 比如Java调用本地方法a 这个本地方法在源码中声明为a 但是没有直接提供a的定义 而是提供了声明b和定义b 然后将a映射到b
    static {
        registerNatives();
    }

public Thread(Runnable target, String name) { // 整个构造方法都不重要 仅仅是做了一些属性赋值工作 没有任何涉及资源开辟
        this(null, target, name, 0);
    }

public Thread(ThreadGroup group, Runnable target, String name,
                  long stackSize) {
        this(group, target, name, stackSize, null, true);
    }

private Thread(ThreadGroup g, Runnable target, String name,
                   long stackSize, AccessControlContext acc,
                   boolean inheritThreadLocals) {
        if (name == null) {
            throw new NullPointerException("name cannot be null");
        }

        this.name = name;

        Thread parent = currentThread(); // 创建线程的线程 谁发起创建线程请求的
        SecurityManager security = System.getSecurityManager();
        if (g == null) {
            /* Determine if it's an applet or not */

            /* If there is a security manager, ask the security manager
               what to do. */
            if (security != null) {
                g = security.getThreadGroup();
            }

            /* If the security manager doesn't have a strong opinion
               on the matter, use the parent thread group. */
            if (g == null) {
                g = parent.getThreadGroup();
            }
        }

        /* checkAccess regardless of whether or not threadgroup is
           explicitly passed in. */
        g.checkAccess();

        /*
         * Do we have the required permissions?
         */
        if (security != null) {
            if (isCCLOverridden(getClass())) {
                security.checkPermission(
                        SecurityConstants.SUBCLASS_IMPLEMENTATION_PERMISSION);
            }
        }

        g.addUnstarted();

        this.group = g;
        this.daemon = parent.isDaemon();
        this.priority = parent.getPriority();
        if (security == null || isCCLOverridden(parent.getClass()))
            this.contextClassLoader = parent.getContextClassLoader();
        else
            this.contextClassLoader = parent.contextClassLoader;
        this.inheritedAccessControlContext =
                acc != null ? acc : AccessController.getContext();
        this.target = target;
        setPriority(priority);
        if (inheritThreadLocals && parent.inheritableThreadLocals != null)
            this.inheritableThreadLocals =
                ThreadLocal.createInheritedMap(parent.inheritableThreadLocals);
        /* Stash the specified stack size in case the VM cares */
        this.stackSize = stackSize;

        /* Set thread ID */
        this.tid = nextThreadID();
    }
```

registerNatives是Java声明的一个本地方法，通过static代码块保证了在构造方法调用时先执行，通过JNI调用在Cpp中的实现。

```cpp
// Thread.c
#define ARRAY_LENGTH(a) (sizeof(a)/sizeof(a[0])) // 计算数组a长度

static JNINativeMethod methods[] = {
    {"start0",           "()V",        (void *)&JVM_StartThread},
    {"stop0",            "(" OBJ ")V", (void *)&JVM_StopThread},
    {"isAlive",          "()Z",        (void *)&JVM_IsThreadAlive},
    {"suspend0",         "()V",        (void *)&JVM_SuspendThread},
    {"resume0",          "()V",        (void *)&JVM_ResumeThread},
    {"setPriority0",     "(I)V",       (void *)&JVM_SetThreadPriority},
    {"yield",            "()V",        (void *)&JVM_Yield},
    {"sleep",            "(J)V",       (void *)&JVM_Sleep},
    {"currentThread",    "()" THD,     (void *)&JVM_CurrentThread},
    {"countStackFrames", "()I",        (void *)&JVM_CountStackFrames},
    {"interrupt0",       "()V",        (void *)&JVM_Interrupt},
    {"isInterrupted",    "(Z)Z",       (void *)&JVM_IsInterrupted},
    {"holdsLock",        "(" OBJ ")Z", (void *)&JVM_HoldsLock},
    {"getThreads",        "()[" THD,   (void *)&JVM_GetAllThreads},
    {"dumpThreads",      "([" THD ")[[" STE, (void *)&JVM_DumpThreads},
    {"setNativeName",    "(" STR ")V", (void *)&JVM_SetNativeThreadName},
};

JNIEXPORT void JNICALL
Java_java_lang_Thread_registerNatives(JNIEnv *env, jclass cls)
{ // JNI默认的两个参数env和cls
    (*env)->RegisterNatives(env, cls, methods, ARRAY_LENGTH(methods)); // methods已经映射表中有多少个
}
```



```cpp
// jni.cpp
JNI_ENTRY(jint, jni_RegisterNatives(JNIEnv *env, jclass clazz,
                                    const JNINativeMethod *methods,
                                    jint nMethods))
  JNIWrapper("RegisterNatives");
  HOTSPOT_JNI_REGISTERNATIVES_ENTRY(env, clazz, (void *) methods, nMethods);
  jint ret = 0;
  DT_RETURN_MARK(RegisterNatives, jint, (const jint&)ret);

  Klass* k = java_lang_Class::as_Klass(JNIHandles::resolve_non_null(clazz));

  for (int index = 0; index < nMethods; index++) {
    const char* meth_name = methods[index].name;
    const char* meth_sig = methods[index].signature;
    int meth_name_len = (int)strlen(meth_name);

    // The class should have been loaded (we have an instance of the class
    // passed in) so the method and signature should already be in the symbol
    // table.  If they're not there, the method doesn't exist.
    TempNewSymbol  name = SymbolTable::probe(meth_name, meth_name_len);
    TempNewSymbol  signature = SymbolTable::probe(meth_sig, (int)strlen(meth_sig));

    if (name == NULL || signature == NULL) {
      ResourceMark rm;
      stringStream st;
      st.print("Method %s.%s%s not found", k->external_name(), meth_name, meth_sig);
      // Must return negative value on failure
      THROW_MSG_(vmSymbols::java_lang_NoSuchMethodError(), st.as_string(), -1);
    }

    bool res = register_native(k, name, signature,
                               (address) methods[index].fnPtr, THREAD);
    if (!res) {
      ret = -1;
      break;
    }
  }
  return ret;
JNI_END
```



```cpp
// jni.cpp
static bool register_native(Klass* k, Symbol* name, Symbol* signature, address entry, TRAPS) {
  Method* method = k->lookup_method(name, signature);
  if (method == NULL) {
    ResourceMark rm;
    stringStream st;
    st.print("Method %s name or signature does not match",
             Method::name_and_sig_as_C_string(k, name, signature));
    THROW_MSG_(vmSymbols::java_lang_NoSuchMethodError(), st.as_string(), false);
  }
  if (!method->is_native()) {
    // trying to register to a non-native method, see if a JVM TI agent has added prefix(es)
    method = find_prefixed_native(k, name, signature, THREAD);
    if (method == NULL) {
      ResourceMark rm;
      stringStream st;
      st.print("Method %s is not declared as native",
               Method::name_and_sig_as_C_string(k, name, signature));
      THROW_MSG_(vmSymbols::java_lang_NoSuchMethodError(), st.as_string(), false);
    }
  }

  if (entry != NULL) {
    method->set_native_function(entry,
      Method::native_bind_event_is_interesting);
  } else {
    method->clear_native_function();
  }
  if (PrintJNIResolving) {
    ResourceMark rm(THREAD);
    tty->print_cr("[Registering JNI native method %s.%s]",
      method->method_holder()->external_name(),
      method->name()->as_C_string());
  }
  return true;
}
```

就是把.java文件中的那些native声明的本地方法跟.cpp文件中的定义映射起来，将来有人调用本地方法，就通过JNI方式调用到cpp中的方法。

## 3 Thread的start方法

```java
// Thread.java
public synchronized void start() { // 启动线程 让线程处于就绪状态 等待被CPU调度
        /**
         * This method is not invoked for the main method thread or "system"
         * group threads created/set up by the VM. Any new functionality added
         * to this method in the future may have to also be added to the VM.
         *
         * A zero status value corresponds to state "NEW".
         */
        if (threadStatus != 0) // 一个线程只能启动一次
            throw new IllegalThreadStateException();

        /* Notify the group that this thread is about to be started
         * so that it can be added to the group's list of threads
         * and the group's unstarted count can be decremented. */
        group.add(this);

        boolean started = false;
        try {
            start0(); // JNI调用 创建线程 回调run方法的实现
            started = true;
        } finally {
            try {
                if (!started) {
                    group.threadStartFailed(this);
                }
            } catch (Throwable ignore) {
                /* do nothing. If start0 threw a Throwable then
                  it will be passed up the call stack */
            }
        }
    }
```



```java
// Thread.java
private native void start0();
```



```cpp
// Thread.c
/*
 * Class:     java_lang_Thread
 * Method:    start0
 * Signature: ()V
 */
JNIEXPORT void JNICALL Java_java_lang_Thread_start0
  (JNIEnv *, jobject);
```



```cpp
// jvm.h
/*
 * java.lang.Thread
 */
JNIEXPORT void JNICALL
JVM_StartThread(JNIEnv *env, jobject thread);
```



```cpp
// jvm.cpp
static void thread_entry(JavaThread* thread, TRAPS) {
  HandleMark hm(THREAD);
  Handle obj(THREAD, thread->threadObj());
  JavaValue result(T_VOID);
  JavaCalls::call_virtual(&result,
                          obj,
                          SystemDictionary::Thread_klass(),
                          vmSymbols::run_method_name(),
                          vmSymbols::void_method_signature(),
                          THREAD); // 线程被调度后要回调Java中的方法(Runnable的run方法)
}


JVM_ENTRY(void, JVM_StartThread(JNIEnv* env, jobject jthread))
  JVMWrapper("JVM_StartThread");
  JavaThread *native_thread = NULL; // cpp级别的线程 里面封装了OS的线程

  // We cannot hold the Threads_lock when we throw an exception,
  // due to rank ordering issues. Example:  we might need to grab the
  // Heap_lock while we construct the exception.
  bool throw_illegal_thread_state = false;

  // We must release the Threads_lock before we can post a jvmti event
  // in Thread::start.
  {
    // Ensure that the C++ Thread and OSThread structures aren't freed before
    // we operate.
    MutexLocker mu(Threads_lock);

    // Since JDK 5 the java.lang.Thread threadStatus is used to prevent
    // re-starting an already started thread, so we should usually find
    // that the JavaThread is null. However for a JNI attached thread
    // there is a small window between the Thread object being created
    // (with its JavaThread set) and the update to its threadStatus, so we
    // have to check for this
    if (java_lang_Thread::thread(JNIHandles::resolve_non_null(jthread)) != NULL) {
      throw_illegal_thread_state = true;
    } else {
      // We could also check the stillborn flag to see if this thread was already stopped, but
      // for historical reasons we let the thread detect that itself when it starts running

      jlong size =
             java_lang_Thread::stackSize(JNIHandles::resolve_non_null(jthread));
      // Allocate the C++ Thread structure and create the native thread.  The
      // stack size retrieved from java is 64-bit signed, but the constructor takes
      // size_t (an unsigned type), which may be 32 or 64-bit depending on the platform.
      //  - Avoid truncating on 32-bit platforms if size is greater than UINT_MAX.
      //  - Avoid passing negative values which would result in really large stacks.
      NOT_LP64(if (size > SIZE_MAX) size = SIZE_MAX;)
      size_t sz = size > 0 ? (size_t) size : 0;
      native_thread = new JavaThread(&thread_entry, sz); // 发生一次系统调用pthread_create 告知OS创建新的线程要执行的函数(thread_entry) 将OS线程封装在cpp线程中

      // At this point it may be possible that no osthread was created for the
      // JavaThread due to lack of memory. Check for this situation and throw
      // an exception if necessary. Eventually we may want to change this so
      // that we only grab the lock if the thread was created successfully -
      // then we can also do this check and throw the exception in the
      // JavaThread constructor.
      if (native_thread->osthread() != NULL) {
        // Note: the current thread is not being used within "prepare".
        native_thread->prepare(jthread);
      }
    }
  }

  if (throw_illegal_thread_state) {
    THROW(vmSymbols::java_lang_IllegalThreadStateException());
  }

  assert(native_thread != NULL, "Starting null thread?");

  if (native_thread->osthread() == NULL) {
    // No one should hold a reference to the 'native_thread'.
    native_thread->smr_delete();
    if (JvmtiExport::should_post_resource_exhausted()) {
      JvmtiExport::post_resource_exhausted(
        JVMTI_RESOURCE_EXHAUSTED_OOM_ERROR | JVMTI_RESOURCE_EXHAUSTED_THREADS,
        os::native_thread_creation_failed_msg());
    }
    THROW_MSG(vmSymbols::java_lang_OutOfMemoryError(),
              os::native_thread_creation_failed_msg());
  }

  Thread::start(native_thread);

JVM_END
```

### 3.1 创建系统线程

```cpp
// thread.cpp
JavaThread::JavaThread(ThreadFunction entry_point, size_t stack_sz) :
                       Thread() { // Cpp级别的线程封装 entry_point新线程被调度起来要执行的函数(Java中Thread的run方法)
  initialize();
  _jni_attach_state = _not_attaching_via_jni;
  set_entry_point(entry_point); // 设置Cpp线程要回调的方法(定义在Java中Runnable的run方法)
  // Create the native thread itself.
  // %note runtime_23
  os::ThreadType thr_type = os::java_thread;
  thr_type = entry_point == &compiler_thread_entry ? os::compiler_thread :
                                                     os::java_thread;
  os::create_thread(this, thr_type, stack_sz); // 发生一次系统调用pthread_create 将entry_point要新建线程开始执行的函数传给了OS 将OS系统级别的线程设置在os_thread中
  // The _osthread may be NULL here because we ran out of memory (too many threads active).
  // We need to throw and OutOfMemoryError - however we cannot do this here because the caller
  // may hold a lock and all locks must be unlocked before throwing the exception (throwing
  // the exception consists of creating the exception object & initializing it, initialization
  // will leave the VM via a JavaCall and then all locks must be unlocked).
  //
  // The thread is still suspended when we reach here. Thread must be explicit started
  // by creator! Furthermore, the thread must also explicitly be added to the Threads list
  // by calling Threads:add. The reason why this is not done here, is because the thread
  // object must be fully initialized (take a look at JVM_Start)
}
```



```cpp
// os_bsd.cpp
bool os::create_thread(Thread* thread, ThreadType thr_type,
                       size_t req_stack_size) { // thread=Cpp级别的线程 封装着要回调的Java方法(Runnable的run方法) 就是OS系统创建的线程需要执行的函数的实参 调用pthread_create系统调用 将OS线程设置到thread中
  assert(thread->osthread() == NULL, "caller responsible");

  // Allocate the OSThread object
  OSThread* osthread = new OSThread(NULL, NULL); // 封装OS系统的线程 里面包裹着真正的线程
  if (osthread == NULL) {
    return false;
  }

  // set the correct thread state
  osthread->set_thread_type(thr_type);

  // Initial state is ALLOCATED but not INITIALIZED
  osthread->set_state(ALLOCATED);

  thread->set_osthread(osthread); // osthread中维护着真正的系统级别线程的id

  // init thread attributes
  pthread_attr_t attr; // pthread_create系统调用创建线程需要指定线程属性 为空就使用默认 线程创建好后再修改属性线程不受影响
  pthread_attr_init(&attr);
  pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);

  // calculate stack size if it's not specified by caller
  size_t stack_size = os::Posix::get_initial_stack_size(thr_type, req_stack_size);
  int status = pthread_attr_setstacksize(&attr, stack_size);
  assert_status(status == 0, status, "pthread_attr_setstacksize");

  ThreadState state;

  {
    pthread_t tid; // pthread_create系统调用创建好线程的id
    int ret = pthread_create(&tid, &attr, (void* (*)(void*)) thread_native_entry, thread); // pthread_create系统调用创建线程成功返回0 thread_native_entry=新建线程要执行的函数 thread=thread_native_entry函数的的实参

    char buf[64];
    if (ret == 0) {
      log_info(os, thread)("Thread started (pthread id: " UINTX_FORMAT ", attributes: %s). ",
        (uintx) tid, os::Posix::describe_pthread_attr(buf, sizeof(buf), &attr));
    } else {
      log_warning(os, thread)("Failed to start thread - pthread_create failed (%s) for attributes: %s.",
        os::errno_name(ret), os::Posix::describe_pthread_attr(buf, sizeof(buf), &attr));
    }

    pthread_attr_destroy(&attr);

    if (ret != 0) {
      // Need to clean up stuff we've allocated so far
      thread->set_osthread(NULL);
      delete osthread;
      return false;
    }

    // Store pthread info into the OSThread
    osthread->set_pthread_id(tid); // 将OS线程设置给osthread thread中持有osthread 这时候thread也就设置好了OS线程

    // Wait until child thread is either initialized or aborted
    {
      Monitor* sync_with_child = osthread->startThread_lock();
      MutexLockerEx ml(sync_with_child, Mutex::_no_safepoint_check_flag);
      while ((state = osthread->get_state()) == ALLOCATED) {
        sync_with_child->wait(Mutex::_no_safepoint_check_flag);
      }
    }

  }

  // Aborted due to thread limit being reached
  if (state == ZOMBIE) {
    thread->set_osthread(NULL);
    delete osthread;
    return false;
  }

  // The thread is returned suspended (in state INITIALIZED),
  // and is started higher up in the call chain
  assert(state == INITIALIZED, "race condition");
  return true;
}
```



### 3.2 线程启动

```cpp
// thread.cpp
void Thread::start(Thread* thread) { // thread是Cpp线程 封装着OS的线程 Java要线程执行的回调
  // Start is different from resume in that its safety is guaranteed by context or
  // being called from a Java method synchronized on the Thread object.
  if (!DisableStartThread) {
    if (thread->is_Java_thread()) { // true
      // Initialize the thread state to RUNNABLE before starting this thread.
      // Can not set it after the thread started because we do not know the
      // exact thread state at that time. It could be in MONITOR_WAIT or
      // in SLEEPING or some other state.
      java_lang_Thread::set_thread_status(((JavaThread*)thread)->threadObj(),
                                          java_lang_Thread::RUNNABLE);
    }
    os::start_thread(thread);
  }
}
```



```cpp
// os.cpp
void os::start_thread(Thread* thread) { // Cpp线程(封装着OS线程+Java要回调的方法)
  // guard suspend/resume
  MutexLockerEx ml(thread->SR_lock(), Mutex::_no_safepoint_check_flag);
  OSThread* osthread = thread->osthread(); // OS线程
  osthread->set_state(RUNNABLE);
  pd_start_thread(thread);
}
```



```cpp
// os_bsd.cpp
void os::pd_start_thread(Thread* thread) { // Cpp线程(封装着OS线程+Java要回调的方法)
  OSThread * osthread = thread->osthread(); // OS线程
  assert(osthread->get_state() != INITIALIZED, "just checking");
  Monitor* sync_with_child = osthread->startThread_lock();
  MutexLockerEx ml(sync_with_child, Mutex::_no_safepoint_check_flag);
  sync_with_child->notify();
}
```



### 3.3 线程回调Java

```cpp
// os_bsd.cpp
static void *thread_native_entry(Thread *thread) { // thread=Cpp线程 初始化的时候封装了要回调执行的Java函数 pthread_create创建线程之后又封装了OS线程 OS线程被CPU调度后执行pthread_create创建时候定义好的执行函数
  // Try to randomize the cache line index of hot stack frames.
  // This helps when threads of the same stack traces evict each other's
  // cache lines. The threads can be either from the same JVM instance, or
  // from different JVM instances. The benefit is especially true for
  // processors with hyperthreading technology.
  static int counter = 0;
  int pid = os::current_process_id();
  alloca(((pid ^ counter++) & 7) * 128);

  thread->initialize_thread_current();

  OSThread* osthread = thread->osthread();
  Monitor* sync = osthread->startThread_lock();

  osthread->set_thread_id(os::Bsd::gettid());

  log_info(os, thread)("Thread is alive (tid: " UINTX_FORMAT ", pthread id: " UINTX_FORMAT ").",
    os::current_thread_id(), (uintx) pthread_self());

#ifdef __APPLE__
  uint64_t unique_thread_id = locate_unique_thread_id(osthread->thread_id());
  guarantee(unique_thread_id != 0, "unique thread id was not found");
  osthread->set_unique_thread_id(unique_thread_id);
#endif
  // initialize signal mask for this thread
  os::Bsd::hotspot_sigmask(thread);

  // initialize floating point control register
  os::Bsd::init_thread_fpu_state();

#ifdef __APPLE__
  // register thread with objc gc
  if (objc_registerThreadWithCollectorFunction != NULL) {
    objc_registerThreadWithCollectorFunction();
  }
#endif

  // handshaking with parent thread
  {
    MutexLockerEx ml(sync, Mutex::_no_safepoint_check_flag);

    // notify parent thread
    osthread->set_state(INITIALIZED);
    sync->notify_all();

    // wait until os::start_thread()
    while (osthread->get_state() == INITIALIZED) {
      sync->wait(Mutex::_no_safepoint_check_flag);
    }
  }

  // call one more level start routine
  thread->run(); // thread是Cpp线程 构造完就赋值了要回调的Java代码 现在回调

  log_info(os, thread)("Thread finished (tid: " UINTX_FORMAT ", pthread id: " UINTX_FORMAT ").",
    os::current_thread_id(), (uintx) pthread_self());

  // If a thread has not deleted itself ("delete this") as part of its
  // termination sequence, we have to ensure thread-local-storage is
  // cleared before we actually terminate. No threads should ever be
  // deleted asynchronously with respect to their termination.
  if (Thread::current_or_null_safe() != NULL) {
    assert(Thread::current_or_null_safe() == thread, "current thread is wrong");
    thread->clear_thread_current();
  }

  return 0;
}
```



```cpp
// thread.cpp
void JavaThread::run() { // Cpp线程的run方法
  // initialize thread-local alloc buffer related fields
  this->initialize_tlab();

  // used to test validity of stack trace backs
  this->record_base_of_stack_pointer();

  // Record real stack base and size.
  this->record_stack_base_and_size();

  this->create_stack_guard_pages();

  this->cache_global_variables();

  // Thread is now sufficient initialized to be handled by the safepoint code as being
  // in the VM. Change thread state from _thread_new to _thread_in_vm
  ThreadStateTransition::transition_and_fence(this, _thread_new, _thread_in_vm);

  assert(JavaThread::current() == this, "sanity check");
  assert(!Thread::current()->owns_locks(), "sanity check");

  DTRACE_THREAD_PROBE(start, this);

  // This operation might block. We call that after all safepoint checks for a new thread has
  // been completed.
  this->set_active_handles(JNIHandleBlock::allocate_block());

  if (JvmtiExport::should_post_thread_life()) {
    JvmtiExport::post_thread_start(this);
  }

  EventThreadStart event;
  if (event.should_commit()) {
    event.set_thread(JFR_THREAD_ID(this));
    event.commit();
  }

  // We call another function to do the rest so we are sure that the stack addresses used
  // from there will be lower than the stack base just computed
  thread_main_inner(); // 在thread_main_inner()方法中回调Java的Thread定义的run方法

  // Note, thread is no longer valid at this point!
}
```



```cpp
// thread.cpp
void JavaThread::thread_main_inner() {
  assert(JavaThread::current() == this, "sanity check");
  assert(this->threadObj() != NULL, "just checking");

  // Execute thread entry point unless this thread has a pending exception
  // or has been stopped before starting.
  // Note: Due to JVM_StopThread we can have pending exceptions already!
  if (!this->has_pending_exception() &&
      !java_lang_Thread::is_stillborn(this->threadObj())) {
    {
      ResourceMark rm(this);
      this->set_native_thread_name(this->get_thread_name());
    }
    HandleMark hm(this);
    this->entry_point()(this, this); // JavaThread是Cpp级别的线程 封装了线程回调Java的逻辑 现在触发回调
  }

  DTRACE_THREAD_PROBE(stop, this);

  this->exit(false);
  this->smr_delete();
}
```

