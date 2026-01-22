---
title: KQueue
date: 2023-03-11 14:23:11
category_bar: true
categories: 笔记
---

## 1 不使用KQueue

```cpp
#include <iostream>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <fcntl.h>

int main()
{
    int sfd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (-1 == sfd)
    {
        std::cout << "[err] socket create: " << errno << std::endl;
        return -1;
    }
    fcntl(sfd, F_SETFL, O_NONBLOCK); // 非阻塞
    struct sockaddr_in sock_addr;
    sock_addr.sin_family = PF_INET;
    sock_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    sock_addr.sin_port = htons(8080);
    int bind_ret = bind(sfd, (struct sockaddr *) &sock_addr, sizeof(sock_addr));
    if (-1 == bind_ret)
    {
        std::cout << "[err] bind: " << errno << std::endl;
        return -1;
    }
    if (-1 == (listen(sfd, 2)))
    {
        std::cout << "[err] listen: " << errno << std::endl;
        return -1;
    }
    for (;;)
    {
        int conn_fd = -1;
        if (-1 == (conn_fd = accept(sfd, (struct sockaddr *) nullptr, nullptr)))
        {
            if (EWOULDBLOCK == errno) continue;
            std::cout << "[err] accept: " << errno << std::endl;
            return -1;
        }
        std::cout << "[succ] conn fd=" << conn_fd << std::endl;
    }
    return 0;
}
```

演示服务端拿到客户端连接的场景，在非阻塞IO下，cpu将陷于for轮询中，而且拿到连接成功socket后还需要在用户层轮询判断IO事件。

## 2 使用KQueue

```cpp
#include <iostream>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <sys/event.h>
#include <sys/time.h>

int main()
{
    int sfd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (-1 == sfd)
    {
        std::cout << "[err] socket create: " << errno << std::endl;
        return -1;
    }
    fcntl(sfd, F_SETFL, O_NONBLOCK); // 非阻塞
    struct sockaddr_in sock_addr;
    sock_addr.sin_family = PF_INET;
    sock_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    sock_addr.sin_port = htons(8080);
    int bind_ret = bind(sfd, (struct sockaddr *) &sock_addr, sizeof(sock_addr));
    if (-1 == bind_ret)
    {
        std::cout << "[err] bind: " << errno << std::endl;
        return -1;
    }
    if (-1 == (listen(sfd, 2)))
    {
        std::cout << "[err] listen: " << errno << std::endl;
        return -1;
    }
    // for (;;)
    // {
    //     int conn_fd = -1;
    //     if (-1 == (conn_fd = accept(sfd, (struct sockaddr *) nullptr, nullptr)))
    //     {
    //         if (EWOULDBLOCK == errno) continue;
    //         std::cout << "[err] accept: " << errno << std::endl;
    //         return -1;
    //     }
    //     std::cout << "[succ] conn fd=" << conn_fd << std::endl;
    // }
    // kqueue实例
    int kfd = kqueue();
    // 注册事件 监听sfd连接
    struct kevent changelist[1];
    EV_SET(&changelist[0], sfd, EVFILT_READ, EV_ADD | EV_ENABLE, 0, 0, 0);
    int register_cnt = kevent(kfd, changelist, 1, nullptr, 0, NULL);
    // kqueue监听
    struct kevent events[1024];
    int ready_cnt = 0;
    struct timespec timeout;
    timeout.tv_sec = 3;
    timeout.tv_nsec = 3 * 1000000;
    for (;;)
    {
        if ((ready_cnt = kevent(kfd, nullptr, 0, events, 1024, &timeout)) == -1)
        {
            std::cout << "[err] kevent: " << errno << std::endl;
            return -1;
        }
        if (ready_cnt == 0)
        {
            std::cout << "没有连接" << std::endl;
            continue;
        }
        std::cout << "ready_cnt=" << ready_cnt << std::endl;
        for (int i = 0; i < ready_cnt; ++i)
        {
            std::cout << "ready_fd=" << events[i].ident << std::endl;
            // 将连接进来的socket继续注册进复用器 关注I/O事件
        }
    }
    return 0;
}
```

## 3 手册

```cpp
KQUEUE(2)                   BSD System Calls Manual                  KQUEUE(2)

NNAAMMEE
     kkqquueeuuee, kkeevveenntt, kkeevveenntt6644 and kkeevveenntt__qqooss -- kernel event notification
     mechanism

LLIIBBRRAARRYY
     Standard C Library (libc, -lc)

SSYYNNOOPPSSIISS
     ##iinncclluuddee <<ssyyss//ttyyppeess..hh>>
     ##iinncclluuddee <<ssyyss//eevveenntt..hh>>
     ##iinncclluuddee <<ssyyss//ttiimmee..hh>>

     _i_n_t
     kkqquueeuuee(_v_o_i_d);

     _i_n_t
     kkeevveenntt(_i_n_t _k_q, _c_o_n_s_t _s_t_r_u_c_t _k_e_v_e_n_t _*_c_h_a_n_g_e_l_i_s_t, _i_n_t _n_c_h_a_n_g_e_s,
         _s_t_r_u_c_t _k_e_v_e_n_t _*_e_v_e_n_t_l_i_s_t, _i_n_t _n_e_v_e_n_t_s,
         _c_o_n_s_t _s_t_r_u_c_t _t_i_m_e_s_p_e_c _*_t_i_m_e_o_u_t);

     _i_n_t
     kkeevveenntt6644(_i_n_t _k_q, _c_o_n_s_t _s_t_r_u_c_t _k_e_v_e_n_t_6_4___s _*_c_h_a_n_g_e_l_i_s_t, _i_n_t _n_c_h_a_n_g_e_s,
         _s_t_r_u_c_t _k_e_v_e_n_t_6_4___s _*_e_v_e_n_t_l_i_s_t, _i_n_t _n_e_v_e_n_t_s, _u_n_s_i_g_n_e_d _i_n_t _f_l_a_g_s,
         _c_o_n_s_t _s_t_r_u_c_t _t_i_m_e_s_p_e_c _*_t_i_m_e_o_u_t);

     _i_n_t
     kkeevveenntt__qqooss(_i_n_t _k_q, _c_o_n_s_t _s_t_r_u_c_t _k_e_v_e_n_t___q_o_s___s _*_c_h_a_n_g_e_l_i_s_t, _i_n_t _n_c_h_a_n_g_e_s,
         _s_t_r_u_c_t _k_e_v_e_n_t___q_o_s___s _*_e_v_e_n_t_l_i_s_t, _i_n_t _n_e_v_e_n_t_s, _v_o_i_d _*_d_a_t_a___o_u_t,
         _s_i_z_e___t _*_d_a_t_a___a_v_a_i_l_a_b_l_e, _u_n_s_i_g_n_e_d _i_n_t _f_l_a_g_s);

     EEVV__SSEETT(_&_k_e_v, _i_d_e_n_t, _f_i_l_t_e_r, _f_l_a_g_s, _f_f_l_a_g_s, _d_a_t_a, _u_d_a_t_a);

     EEVV__SSEETT6644(_&_k_e_v, _i_d_e_n_t, _f_i_l_t_e_r, _f_l_a_g_s, _f_f_l_a_g_s, _d_a_t_a, _u_d_a_t_a, _e_x_t_[_0_],
         _e_x_t_[_1_]);

     EEVV__SSEETT__QQOOSS(_&_k_e_v, _i_d_e_n_t, _f_i_l_t_e_r, _f_l_a_g_s, _q_o_s, _u_d_a_t_a, _f_f_l_a_g_s, _x_f_l_a_g_s, _d_a_t_a,
         _e_x_t_[_0_], _e_x_t_[_1_], _e_x_t_[_2_], _e_x_t_[_3_]);

DDEESSCCRRIIPPTTIIOONN
     The kkqquueeuuee() system call allocates a kqueue file descriptor.  This file
     descriptor provides a generic method of notifying the user when a kernel
     event (kevent) happens or a condition holds, based on the results of
     small pieces of kernel code termed filters.

     A kevent is identified by an (ident, filter, and optional udata value)
     tuple.  It specifies the interesting conditions to be notified about for
     that tuple. An (ident, filter, and optional udata value) tuple can only
     appear once in a given kqueue.  Subsequent attempts to register the same
     tuple for a given kqueue will result in the replacement of the conditions
     being watched, not an addition.  Whether the udata value is considered as
     part of the tuple is controlled by the EV_UDATA_SPECIFIC flag on the
     kevent.

     The filter identified in a kevent is executed upon the initial registra-
     tion of that event in order to detect whether a preexisting condition is
     present, and is also executed whenever an event is passed to the filter
     for evaluation.  If the filter determines that the condition should be
     reported, then the kevent is placed on the kqueue for the user to
     retrieve.

     The filter is also run when the user attempts to retrieve the kevent from
     the kqueue.  If the filter indicates that the condition that triggered
     the event no longer holds, the kevent is removed from the kqueue and is
     not returned.

     Multiple events which trigger the filter do not result in multiple
     kevents being placed on the kqueue; instead, the filter will aggregate
     the events into a single struct kevent.  Calling cclloossee() on a file
     descriptor will remove any kevents that reference the descriptor.

     The kkqquueeuuee() system call creates a new kernel event queue and returns a
     descriptor.  The queue is not inherited by a child created with fork(2).

     The kkeevveenntt,,() kkeevveenntt6644() and kkeevveenntt__qqooss() system calls are used to regis-
     ter events with the queue, and return any pending events to the user.
     The _c_h_a_n_g_e_l_i_s_t argument is a pointer to an array of _k_e_v_e_n_t_, _k_e_v_e_n_t_6_4___s or
     _k_e_v_e_n_t___q_o_s___s structures, as defined in <_s_y_s_/_e_v_e_n_t_._h>.  All changes con-
     tained in the _c_h_a_n_g_e_l_i_s_t are applied before any pending events are read
     from the queue.  The _n_c_h_a_n_g_e_s argument gives the size of _c_h_a_n_g_e_l_i_s_t.

     The _e_v_e_n_t_l_i_s_t argument is a pointer to an array of out _k_e_v_e_n_t_, _k_e_v_e_n_t_6_4___s
     or _k_e_v_e_n_t___q_o_s___s structures.  The _n_e_v_e_n_t_s argument determines the size of
     _e_v_e_n_t_l_i_s_t.

     The _d_a_t_a___o_u_t argument provides space for extra out data provided by spe-
     cific filters.  The _d_a_t_a___a_v_a_i_l_a_b_l_e argument's contents specified the
     space available in the data pool on input, and contains the amount still
     remaining on output.  If the KEVENT_FLAG_STACK_DATA flag is specified on
     the system call, the data is allocated from the pool in stack order
     instead of typical heap order.

     If _t_i_m_e_o_u_t is a non-NULL pointer, it specifies a maximum interval to wait
     for an event, which will be interpreted as a struct timespec.  If _t_i_m_e_o_u_t
     is a NULL pointer, both kkeevveenntt() and kkeevveenntt6644() wait indefinitely.  To
     effect a poll, the _f_l_a_g_s argument to kkeevveenntt6644() or kkeevveenntt__qqooss() can
     include the KEVENT_FLAG_IMMEDIATE value to indicate an immediate timeout.
     Alternatively, the _t_i_m_e_o_u_t argument should be non-NULL, pointing to a
     zero-valued _t_i_m_e_s_p_e_c structure.  The same array may be used for the
     _c_h_a_n_g_e_l_i_s_t and _e_v_e_n_t_l_i_s_t.

     The EEVV__SSEETT() macro is provided for ease of initializing a _k_e_v_e_n_t struc-
     ture. Similarly, EEVV__SSEETT6644() initializes a _k_e_v_e_n_t_6_4___s structure and
     EEVV__SSEETT__QQOOSS() initializes a _k_e_v_e_n_t___q_o_s___s structure.

     The _k_e_v_e_n_t_, _k_e_v_e_n_t_6_4___s and _k_e_v_e_n_t___q_o_s___s structures are defined as:

     struct kevent {
             uintptr_t       ident;          /* identifier for this event */
             int16_t         filter;         /* filter for event */
             uint16_t        flags;          /* general flags */
             uint32_t        fflags;         /* filter-specific flags */
             intptr_t        data;           /* filter-specific data */
             void            *udata;         /* opaque user data identifier */
     };

     struct kevent64_s {
             uint64_t        ident;          /* identifier for this event */
             int16_t         filter;         /* filter for event */
             uint16_t        flags;          /* general flags */
             uint32_t        fflags;         /* filter-specific flags */
             int64_t         data;           /* filter-specific data */
             uint64_t        udata;          /* opaque user data identifier */
             uint64_t        ext[2];         /* filter-specific extensions */
     };

     struct kevent_qos_s {
             uint64_t        ident;          /* identifier for this event */
             int16_t         filter;         /* filter for event */
             uint16_t        flags;          /* general flags */
             uint32_t        qos;            /* quality of service when servicing event */
             uint64_t        udata;          /* opaque user data identifier */
             uint32_t        fflags;         /* filter-specific flags */
             uint32_t        xflags;         /* extra filter-specific flags */
             int64_t         data;           /* filter-specific data */
             uint64_t        ext[4];         /* filter-specific extensions */
     };

     ----

     The fields of _s_t_r_u_c_t _k_e_v_e_n_t_, _s_t_r_u_c_t _k_e_v_e_n_t_6_4___s and _s_t_r_u_c_t _k_e_v_e_n_t___q_o_s___s
     are:

     ident      Value used to identify the source of the event.  The exact
                interpretation is determined by the attached filter, but often
                is a file descriptor.

     filter     Identifies the kernel filter used to process this event.  The
                pre-defined system filters are described below.

     flags      Actions to perform on the event.

     fflags     Filter-specific flags.

     data       Filter-specific data value.

     udata      Opaque user-defined value passed through the kernel unchanged.
                It can optionally be part of the uniquing decision of the
                kevent system

     In addition, _s_t_r_u_c_t _k_e_v_e_n_t_6_4___s contains:

     ext[2]     This field stores extensions for the event's filter. What type
                of extension depends on what type of filter is being used.

     In addition, _s_t_r_u_c_t _k_e_v_e_n_t___q_o_s___s contains:

     xflags     Extra filter-specific flags.

     ext[4]     The QoS variant provides twice as many extension values for
                filter-specific uses.

     ----

     The _f_l_a_g_s field can contain the following values:

     EV_ADD         Adds the event to the kqueue.  Re-adding an existing event
                    will modify the parameters of the original event, and not
                    result in a duplicate entry.  Adding an event automati-
                    cally enables it, unless overridden by the EV_DISABLE
                    flag.

     EV_ENABLE      Permit kkeevveenntt,,() kkeevveenntt6644() and kkeevveenntt__qqooss() to return the
                    event if it is triggered.

     EV_DISABLE     Disable the event so kkeevveenntt,,() kkeevveenntt6644() and kkeevveenntt__qqooss()
                    will not return it.  The filter itself is not disabled.

     EV_DELETE      Removes the event from the kqueue.  Events which are
                    attached to file descriptors are automatically deleted on
                    the last close of the descriptor.

     EV_RECEIPT     This flag is useful for making bulk changes to a kqueue
                    without draining any pending events. When passed as input,
                    it forces EV_ERROR to always be returned.  When a filter
                    is successfully added, the _d_a_t_a field will be zero.

     EV_ONESHOT     Causes the event to return only the first occurrence of
                    the filter being triggered.  After the user retrieves the
                    event from the kqueue, it is deleted.

     EV_CLEAR       After the event is retrieved by the user, its state is
                    reset.  This is useful for filters which report state
                    transitions instead of the current state.  Note that some
                    filters may automatically set this flag internally.

     EV_EOF         Filters may set this flag to indicate filter-specific EOF
                    condition.

     EV_OOBAND      Read filter on socket may set this flag to indicate the
                    presence of out of band data on the descriptor.

     EV_ERROR       See _R_E_T_U_R_N _V_A_L_U_E_S below.

     ----

     The predefined system filters are listed below.  Arguments may be passed
     to and from the filter via the _d_a_t_a_, _f_f_l_a_g_s and optionally _x_f_l_a_g_s fields
     in the _k_e_v_e_n_t_, _k_e_v_e_n_t_6_4___s or _k_e_v_e_n_t___q_o_s___s structure.

     EVFILT_READ      Takes a file descriptor as the identifier, and returns
                      whenever there is data available to read.  The behavior
                      of the filter is slightly different depending on the
                      descriptor type.

                      Sockets
                          Sockets which have previously been passed to
                          lliisstteenn() return when there is an incoming connection
                          pending.  _d_a_t_a contains the size of the listen back-
                          log.

                          Other socket descriptors return when there is data
                          to be read, subject to the SO_RCVLOWAT value of the
                          socket buffer.  This may be overridden with a per-
                          filter low water mark at the time the filter is
                          added by setting the NOTE_LOWAT flag in _f_f_l_a_g_s, and
                          specifying the new low water mark in _d_a_t_a.  The
                          derived per filter low water mark value is, however,
                          bounded by socket receive buffer's high and low
                          water mark values.  On return, _d_a_t_a contains the
                          number of bytes of protocol data available to read.

                          The presence of EV_OOBAND in _f_l_a_g_s, indicates the
                          presence of out of band data on the socket _d_a_t_a
                          equal to the potential number of OOB bytes availble
                          to read.

                          If the read direction of the socket has shutdown,
                          then the filter also sets EV_EOF in _f_l_a_g_s, and
                          returns the socket error (if any) in _f_f_l_a_g_s.  It is
                          possible for EOF to be returned (indicating the con-
                          nection is gone) while there is still data pending
                          in the socket buffer.

                      Vnodes
                          Returns when the file pointer is not at the end of
                          file.  _d_a_t_a contains the offset from current posi-
                          tion to end of file, and may be negative.

                      Fifos, Pipes
                          Returns when there is data to read; _d_a_t_a contains
                          the number of bytes available.

                          When the last writer disconnects, the filter will
                          set EV_EOF in _f_l_a_g_s.  This may be cleared by passing
                          in EV_CLEAR, at which point the filter will resume
                          waiting for data to become available before return-
                          ing.

                      Device nodes
                          Returns when there is data to read from the device;
                          _d_a_t_a contains the number of bytes available.  If the
                          device does not support returning number of bytes,
                          it will not allow the filter to be attached.  How-
                          ever, if the NOTE_LOWAT flag is specified and the
                          _d_a_t_a field contains 1 on input, those devices will
                          attach - but cannot be relied upon to provide an
                          accurate count of bytes to be read on output.

     EVFILT_EXCEPT    Takes a descriptor as the identifier, and returns when-
                      ever one of the specified exceptional conditions has
                      occurred on the descriptor. Conditions are specified in
                      _f_f_l_a_g_s.  Currently, this filter can be used to monitor
                      the arrival of out-of-band data on a socket descriptor
                      using the filter flag NOTE_OOB.

                      If the read direction of the socket has shutdown, then
                      the filter also sets EV_EOF in _f_l_a_g_s, and returns the
                      socket error (if any) in _f_f_l_a_g_s.

     EVFILT_WRITE     Takes a file descriptor as the identifier, and returns
                      whenever it is possible to write to the descriptor.  For
                      sockets, pipes and fifos, _d_a_t_a will contain the amount
                      of space remaining in the write buffer.  The filter will
                      set EV_EOF when the reader disconnects, and for the fifo
                      case, this may be cleared by use of EV_CLEAR.  Note that
                      this filter is not supported for vnodes.

                      For sockets, the low water mark and socket error han-
                      dling is identical to the EVFILT_READ case.

     EVFILT_AIO       This filter is currently unsupported.

     EVFILT_VNODE     Takes a file descriptor as the identifier and the events
                      to watch for in _f_f_l_a_g_s, and returns when one or more of
                      the requested events occurs on the descriptor.  The
                      events to monitor are:

                      NOTE_DELETE    The uunnlliinnkk() system call was called on
                                     the file referenced by the descriptor.

                      NOTE_WRITE     A write occurred on the file referenced
                                     by the descriptor.

                      NOTE_EXTEND    The file referenced by the descriptor was
                                     extended.

                      NOTE_ATTRIB    The file referenced by the descriptor had
                                     its attributes changed.

                      NOTE_LINK      The link count on the file changed.

                      NOTE_RENAME    The file referenced by the descriptor was
                                     renamed.

                      NOTE_REVOKE    Access to the file was revoked via
                                     revoke(2) or the underlying fileystem was
                                     unmounted.

                      NOTE_FUNLOCK   The file was unlocked by calling flock(2)
                                     or close(2)

                      On return, _f_f_l_a_g_s contains the filter-specific flags
                      which are associated with the triggered events seen by
                      this filter.

     EVFILT_PROC      Takes the process ID to monitor as the identifier and
                      the events to watch for in _f_f_l_a_g_s, and returns when the
                      process performs one or more of the requested events.
                      If a process can normally see another process, it can
                      attach an event to it.  The events to monitor are:

                      NOTE_EXIT    The process has exited.

                      NOTE_EXITSTATUS
                                   The process has exited and its exit status
                                   is in filter specific data. Valid only on
                                   child processes and to be used along with
                                   NOTE_EXIT.

                      NOTE_FORK    The process created a child process via
                                   fork(2) or similar call.

                      NOTE_EXEC    The process executed a new process via
                                   execve(2) or similar call.

                      NOTE_SIGNAL  The process was sent a signal. Status can
                                   be checked via waitpid(2) or similar call.

                      NOTE_REAP    The process was reaped by the parent via
                                   wait(2) or similar call. Deprecated, use
                                   NOTE_EXIT.

                      On return, _f_f_l_a_g_s contains the events which triggered
                      the filter.

     EVFILT_SIGNAL    Takes the signal number to monitor as the identifier and
                      returns when the given signal is generated for the
                      process.  This coexists with the ssiiggnnaall() and
                      ssiiggaaccttiioonn() facilities, and has a lower precedence.
                      Only signals sent to the process, not to a particular
                      thread, will trigger the filter. The filter will record
                      all attempts to deliver a signal to a process, even if
                      the signal has been marked as SIG_IGN.  Event notifica-
                      tion happens before normal signal delivery processing.
                      _d_a_t_a returns the number of times the signal has been
                      generated since the last call to kkeevveenntt().  This filter
                      automatically sets the EV_CLEAR flag internally.

     EVFILT_MACHPORT  Takes the name of a mach port, or port set, in _i_d_e_n_t and
                      waits until a message is enqueued on the port or port
                      set. When a message is detected, but not directly
                      received by the kevent call, the name of the specific
                      port where the message is enqueued is returned in _d_a_t_a.
                      If _f_f_l_a_g_s contains MACH_RCV_MSG, the ext[0] and ext[1]
                      flags are assumed to contain a pointer to the buffer
                      where the message is to be received and the size of the
                      receive buffer, respectively.  If MACH_RCV_MSG is
                      specifed, yet the buffer size in ext[1] is zero, The
                      space for the buffer may be carved out of the data_out
                      area provided to kkeevveenntt__qqooss() if there is enough space
                      remaining there.

     EVFILT_TIMER     Establishes an interval timer identified by _i_d_e_n_t where
                      _d_a_t_a specifies the timeout period (in milliseconds).

                      _f_f_l_a_g_s can include one of the following flags to specify
                      a different unit:

                      NOTE_SECONDS   _d_a_t_a is in seconds

                      NOTE_USECONDS  _d_a_t_a is in microseconds

                      NOTE_NSECONDS  _d_a_t_a is in nanoseconds

                      NOTE_MACHTIME  _d_a_t_a is in Mach absolute time units

                      _f_f_l_a_g_s can also include NOTE_ABSOLUTE, which establishes
                      an EV_ONESHOT timer with an absolute deadline instead of
                      an interval.  The absolute deadline is expressed in
                      terms of gettimeofday(2).  With NOTE_MACHTIME, the dead-
                      line is expressed in terms of mmaacchh__aabbssoolluuttee__ttiimmee().

                      The timer can be coalesced with other timers to save
                      power. The following flags can be set in _f_f_l_a_g_s to mod-
                      ify this behavior:

                      NOTE_CRITICAL    override default power-saving tech-
                                       niques to more strictly respect the
                                       leeway value

                      NOTE_BACKGROUND  apply more power-saving techniques to
                                       coalesce this timer with other timers

                      NOTE_LEEWAY      _e_x_t_[_1_] holds user-supplied slop in
                                       deadline for timer coalescing.

                      The timer will be periodic unless EV_ONESHOT is speci-
                      fied.  On return, _d_a_t_a contains the number of times the
                      timeout has expired since the last arming or last deliv-
                      ery of the timer event.

                      This filter automatically sets the EV_CLEAR flag.

     ----

     In the _e_x_t_[_2_] field of the _k_e_v_e_n_t_6_4___s struture, _e_x_t_[_0_] is only used with
     the EVFILT_MACHPORT filter.  With other filters, _e_x_t_[_0_] is passed through
     kkeevveenntt6644() much like _u_d_a_t_a.  _e_x_t_[_1_] can always be used like _u_d_a_t_a.  For
     the use of ext[0], see the EVFILT_MACHPORT filter above.

RREETTUURRNN VVAALLUUEESS
     The kkqquueeuuee() system call creates a new kernel event queue and returns a
     file descriptor.  If there was an error creating the kernel event queue,
     a value of -1 is returned and errno set.

     The kkeevveenntt(), kkeevveenntt6644() and kkeevveenntt__qqooss() system calls return the number
     of events placed in the _e_v_e_n_t_l_i_s_t, up to the value given by _n_e_v_e_n_t_s.  If
     an error occurs while processing an element of the _c_h_a_n_g_e_l_i_s_t and there
     is enough room in the _e_v_e_n_t_l_i_s_t, then the event will be placed in the
     _e_v_e_n_t_l_i_s_t with EV_ERROR set in _f_l_a_g_s and the system error in _d_a_t_a.  Oth-
     erwise, -1 will be returned, and errno will be set to indicate the error
     condition.  If the time limit expires, then kkeevveenntt(), kkeevveenntt6644() and
     kkeevveenntt__qqooss() return 0.

EERRRROORRSS
     The kkqquueeuuee() system call fails if:

     [ENOMEM]           The kernel failed to allocate enough memory for the
                        kernel queue.

     [EMFILE]           The per-process descriptor table is full.

     [ENFILE]           The system file table is full.

     The kkeevveenntt() and kkeevveenntt6644() system calls fail if:

     [EACCES]           The process does not have permission to register a
                        filter.

     [EFAULT]           There was an error reading or writing the _k_e_v_e_n_t or
                        _k_e_v_e_n_t_6_4___s structure.

     [EBADF]            The specified descriptor is invalid.

     [EINTR]            A signal was delivered before the timeout expired and
                        before any events were placed on the kqueue for
                        return.

     [EINVAL]           The specified time limit or filter is invalid.

     [ENOENT]           The event could not be found to be modified or
                        deleted.

     [ENOMEM]           No memory was available to register the event.

     [ESRCH]            The specified process to attach to does not exist.

SSEEEE AALLSSOO
     aio_error(2), aio_read(2), aio_return(2), read(2), select(2),
     sigaction(2), write(2), signal(3)

HHIISSTTOORRYY
     The kkqquueeuuee() and kkeevveenntt() system calls first appeared in FreeBSD 4.1.

AAUUTTHHOORRSS
     The kkqquueeuuee() system and this manual page were written by Jonathan Lemon
     <jlemon@FreeBSD.org>.

BBUUGGSS
     Not all filesystem types support kqueue-style notifications.  And even
     some that do, like some remote filesystems, may only support a subset of
     the notification semantics described here.

BSD                            October 21, 2008                            BSD

```

重点

* 通过kqueue()系统调用创建实例
* EV_SET()宏创建事件数据结构kevent
  * 关注哪个fd
  * 关注该fd的什么IO类型事件(可读/可写...)
  * 将该事件操作(注册/移除/覆盖更新...)到kqueue队列中
* kevent()系统调用组合实参有两个用途
  * 注册事件到kqueue中：形参changelist=指针指向内存存放待注册事件，形参nchanges=多少个fd事件要注册
  * 复用器返回：形参eventlist=指针指向内存存放就绪的fd，形参nevents=存放就绪fd数量，返回值=状态就绪的事件数量
