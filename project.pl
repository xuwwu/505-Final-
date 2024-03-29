%% This server gets swamped by its client, filling in the buffers for the
%% incoming sockets. The client performs socket_select on the sockets it
%% writes to, and from time to time those sockets would become unavailable for
%% writing. 

:- compiler_options([xpp_on]).
#include "socket_defs_xsb.h"
#include "timer_defs_xsb.h"
#include "char_defs.h"

#define Q_LENGTH  20

:- import 
     socket/2, socket_bind/3, socket_listen/3, socket_accept/3, 
     socket_set_option/3, socket_close/2, socket_get0/3,
     socket_put/3 from socket.

:- import file_close/1, fmt_write/3 from file_io.
:- import ground/1 from basics.

%% Port on which the server is listening
xsb_port(6025).

tryN(Attempts, Call, SuccessGoal, FailGoal, Ecode) :-
	Attempts > 0,
	(call(Call), Ecode == SOCK_OK, write('Success: '), call(SuccessGoal), !
	; sleep(3), Attempts1 is Attempts-1,
	  write('Retrying: '), writeln(Call),
	  tryN(Attempts1,Call,SuccessGoal,FailGoal,Ecode)
	).
	
tryN(Attempts, _Call, _SuccessGoal, FailGoal, _Ecode) :-
	Attempts < 1, write('Giving up: '), call(FailGoal), fail.
	
server :-
	socket(Sockfd0, ErrCode),
	(ErrCode =\= SOCK_OK
	-> writeln('Cannot open socket'), fail
	; true),
	writeln(socket(Sockfd0, ErrCode)),
	socket_set_option(Sockfd0,linger,SOCK_NOLINGER),
	xsb_port(XSBPort),
	tryN(4,
	     socket_bind(Sockfd0, XSBPort, ErrBind),
	     writeln(socket_bind(Sockfd0, XSBPort, ErrBind)),
	     writeln('Cannot bind'),
	     ErrBind
	    ),

	socket_listen(Sockfd0,Q_LENGTH, ErrListen),
	writeln(socket_listen(Sockfd0,Q_LENGTH, ErrListen)),

	tryN(4,
	     socket_accept(Sockfd0, Sockfd0_out1, ErrorCode),
	     writeln(socket_accept1(Sockfd0, Sockfd0_out1, ErrorCode)),
	     writeln('Cannot accept connection1'),
	     ErrorCode
	    ),
	
	tryN(4,
	     socket_accept(Sockfd0, Sockfd0_out2, ErrorCode2),
             writeln(socket_accept2(Sockfd0, Sockfd0_out2, ErrorCode2)),
	     writeln('Cannot accept connection2'),
	     ErrorCode2
	    ),

	server_loop(Sockfd0_out1, Sockfd0_out2).

server_loop(Sockfd0, Sockfd1) :-
    sleep(1),
    socket_get0(Sockfd0,Char,Ecode),
    %% writeln(socket_get1(Sockfd0,Char,Ecode)),
    (Ecode =\= 0, Ecode =\= TIMEOUT_ERR
    ->  write('Error code: '), write(Ecode), writeln(' ...exiting.')
    ;  
	((Char==CH_EOF_C; Char == 4)
	->  writeln('Client quits...'),
	    socket_close(Sockfd0,_)
	;   ground(Char)
	->  fmt_write('%c', f(Char))
	;   fail
        )
    ),
	sleep(1),
    socket_get0(Sockfd1, Char1,Ecode1),
    %%writeln(socket_get2(Sockfd1, Char1,Ecode1)),
    (Ecode1 =\= 0, Ecode1 =\= TIMEOUT_ERR
    ->  write('Error code: '), write(Ecode1), writeln(' ...exiting.')
    ;
	((Char1==CH_EOF_C; Char1 == 4)
    	->  writeln('Client quits...'),
            socket_close(Sockfd1,_)
        ;   ground(Char1)
	->  fmt_write('%c', f(Char1)),fail
        ;   fail
        )
  ).

server_loop(Sockfd0, Sockfd1) :- server_loop(Sockfd0, Sockfd1).

