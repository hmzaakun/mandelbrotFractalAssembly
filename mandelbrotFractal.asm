; external functions from X11 library
extern XOpenDisplay
extern XDisplayName
extern XCloseDisplay
extern XCreateSimpleWindow
extern XMapWindow
extern XRootWindow
extern XSelectInput
extern XFlush
extern XCreateGC
extern XSetForeground
extern XDrawLine
extern XNextEvent

; external functions from stdio library (ld-linux-x86-64.so.2)    
extern printf
extern exit

%define	StructureNotifyMask	131072
%define KeyPressMask		1
%define ButtonPressMask		4
%define MapNotify		19
%define KeyPress		2
%define ButtonPress		4
%define Expose			12
%define ConfigureNotify		22
%define CreateNotify 16
%define QWORD	8
%define DWORD	4
%define WORD	2
%define BYTE	1

global main

section .bss
display_name:	resq	1
screen:			resd	1
depth:         	resd	1
connection:    	resd	1
width:         	resd	1
height:        	resd	1
window:		resq	1
gc:		resq	1


x       resd 1
y       resd 1

c_r     resq 1
c_i     resq 1
z_r     resq 1
z_i     resq 1
i       resd 1
tmp     resq 1
imagex  resd 1
imagey  resd 1


section .data

event:		times	24 dq 0
x1              dq -2.1
x2              dq  0.6
y1              dq -1.2
y2              dq  1.2
zoom            dq  100.
i_max   		dd  50
deux             dq  2.0
quatre            dq  4.0


section .text
	
;##################################################
;########### PROGRAMME PRINCIPAL ##################
;##################################################

main:
xor     rdi,rdi
call    XOpenDisplay	; Création de display
mov     qword[display_name],rax	; rax=nom du display

; display_name structure
; screen = DefaultScreen(display_name);
mov     rax,qword[display_name]
mov     eax,dword[rax+0xe0]
mov     dword[screen],eax

mov rdi,qword[display_name]
mov esi,dword[screen]
call XRootWindow
mov rbx,rax

mov rdi,qword[display_name]
mov rsi,rbx
mov rdx,10
mov rcx,10
mov r8,400	; largeur
mov r9,400	; hauteur
push 0xFFFFFF	; background  0xRRGGBB
push 0x00FF00
push 1
call XCreateSimpleWindow
mov qword[window],rax

mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,131077 ;131072
call XSelectInput

mov rdi,qword[display_name]
mov rsi,qword[window]
call XMapWindow

mov rsi,qword[window]
mov rdx,0
mov rcx,0
call XCreateGC
mov qword[gc],rax

mov rdi,qword[display_name]
mov rsi,qword[gc]
mov rdx,0x000000	; Couleur du crayon
call XSetForeground

boucle: ; boucle de gestion des évènements
mov rdi,qword[display_name]
mov rsi,event
call XNextEvent

cmp dword[event],ConfigureNotify	; à l'apparition de la fenêtre
je dessin							; on saute au label 'dessin'

cmp dword[event],KeyPress			; Si on appuie sur une touche
je closeDisplay						; on saute au label 'closeDisplay' qui ferme la fenêtre
jmp boucle

;#########################################
;#		DEBUT DE LA ZONE DE DESSIN		 #
;#########################################
dessin:
;imagex = (x2 - x1) * zoom
movsd        xmm0, [x2]   ;mov x2 dans xmm0 (movsd car 64bits)
subsd        xmm0, [x1]   ; xmm0= xmm0 - x1 
mulsd         xmm0, [zoom]; xmm0=xmm0*zoom
cvtsd2si     eax,xmm0     ; on convertit xmm0 qui est un flottant  en eax qui est un entier
mov        dword[imagex],eax ; on mov eax dans imagex



;imagiey = (y2 - y1) * zoom
movsd        xmm0, [y2]
subsd        xmm0, [y1]
mulsd         xmm0, [zoom]
cvtsd2si     eax,xmm0
mov        dword[imagey],eax



;x=0
mov dword[x],0

;bouclex for (x = 0; x < imagex; x++)
bouclex:
mov eax,dword[x]  ;mov x dans eax
cmp eax,dword[imagex] ; on compare imagex et x
jae finbouclex     ; si x est sup ou égal à imagex on saute vers finbouclex
    ;mettre y=0
    mov dword[y],0  


    ;boucley for (y = 0; y < imagey; y++)
boucley:
    mov eax , dword[y]
    cmp eax,dword[imagey]
    jae finboucley
    

	; c_r = x / zoom + x1

    
    cvtsi2sd xmm0,[x] ;on convertit x qui est un entier  en xmm0 qui est un flottant
    divsd xmm0, [zoom] ; xmm0=xmm0/zoom
    addsd xmm0, [x1]   ; xmm0=xmm0+x1
    movsd [c_r], xmm0  ; on met le resultat de xmm0 dans c_r
	
    
    ; c_i = y / zoom + y1
    
	cvtsi2sd xmm0, [y] ;on convertit y qui est un entier  en xmm0 qui est un flottant (on convertit un entier en float)
	divsd xmm0, [zoom]
	addsd xmm0, [y1]
	movsd [c_i], xmm0
    
    ; z_r = 0
    mov qword [z_r], 0
    ; z_i = 0
    mov qword [z_i], 0
    ; i = 0
    mov dword [i], 0
    
    
faire:
 
    movsd xmm4,[z_r] ; on met xmm4 dans z_r
    movsd [tmp], xmm4 ; puis on met xmm4 dans temp  donc z_r=xmm4 puis xmm4=tmp
   
	; z_r = z_r * z_r - z_i * z_i + c_r
   
    mulsd xmm4, xmm4 ; z_r = z_r*z_r
    movsd xmm6, [z_i] ; on met z_i dans xmm6
    mulsd xmm6, xmm6 ; xmm6 = z_i * z_i
    subsd xmm4, xmm6 ; xmm4 = z_r*z_r - z_i * z_i
    addsd xmm4,[c_r] ; xmm4 = z_r*z_r - z_i * z_i + c_r
    movsd [z_r], xmm4 ; on stocke le resultat de xmm4 qui est z_r*z_r - z_i * z_i + c_r dans z_r
	
    ; z_i = 2 * z_i * tmp + c_i
    movsd xmm7,  [z_i] ; on stocke z_i dans xmm7
    mulsd xmm7,  [deux]; xmm7 = xmm7 * 2.0  nous avons créé une variable auparavant (deux   dq  2.0) pour que 2 devienne un nombre flottant et qu'on puisse le calculer avec xmm
    mulsd xmm7,  [tmp] ; xmm7 = xmm7 * tmp
    addsd xmm7,  [c_i] ; xmm7 = xmm7 + c_i
    movsd [z_i], xmm7 ; on range le résultat dans z_i
    
    ; inc ++i
    
    inc dword[i]

   
   
     

      ; z_r * z_r + z_i * z_i 
    movsd xmm8,[z_r] 
    mulsd xmm8, xmm8
    movsd xmm9,[z_i]
    mulsd xmm9, xmm9
    addsd xmm9, xmm8
    
    
    
    ; si xmm9 >= 4 jump vers siimax
    ucomisd xmm9,[quatre] ; cmp n 'est plus utilisable pour comparer car nous utilisons des nombres flottants ici ucomisd car ce sont des valeurs de 64bits
    jae siimax
    
    ; i < i_max 

    mov eax, dword[i]
    cmp eax, dword [i_max]
    ;on saute au debut si on est en dessous de i max
    jb faire
    
siimax:


    mov eax, dword[i]
    cmp eax, dword[i_max]
    jne couleur ; si i != imax jump couleur
    mov rdi,qword[display_name]
    mov rsi,qword[gc]
    mov edx, 0x000000       	
    call XSetForeground
                        ; coordonnées de la ligne 1
                        ; dessin de la ligne 1
    mov rdi,qword[display_name]
    mov rsi,qword[window]
    mov rdx,qword[gc]
    mov ecx,dword[x]	; coordonnée source en x
     mov r8d,dword[y]	; coordonnée source en y
    mov r9d,dword[x]	; coordonnée destination en x
    push qword[y]		; coordonnée destination en y
    call XDrawLine
	jmp pixelfait
  
couleur: 
 
  
mov rdi,qword[display_name]
mov rsi,qword[gc]



mov eax, 255
mul dword [i] ;edx:eax = 255 * i
div dword [i_max] ;eax = edx:eax /imax

mov edx, eax
	
call XSetForeground

mov rdi,qword[display_name]
mov rsi,qword[window]
mov rdx,qword[gc]
mov ecx,dword[x]	; coordonnée source en x
 mov r8d,dword[y]	; coordonnée source en y
mov r9d,dword[x]	; coordonnée destination en x
push qword[y]		; coordonnée destination en y
call XDrawLine

 
pixelfait:
	inc dword[y]
	jmp boucley
	finboucley:

	   
	 
	inc dword[x]
	jmp bouclex
	finbouclex:



    
   
   
    

; ############################
; # FIN DE LA ZONE DE DESSIN #
; ############################
jmp flush

flush:
mov rdi,qword[display_name]
call XFlush
jmp boucle
mov rax,34
syscall

closeDisplay:
    mov     rax,qword[display_name]
    mov     rdi,rax
    call    XCloseDisplay
    xor	    rdi,rdi
    call    exit
