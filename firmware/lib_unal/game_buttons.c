#include <generated/csr.h>

#ifdef CSR_GAME_BUTTONS_BASE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <generated/soc.h>
#include <system.h>
#include <irq.h>

#include "game_buttons.h"

void button_debounce(void){
    busy_wait(40);
}

void game_buttons_isr(void){
    unsigned int buttons = game_buttons_ev_pending_read() & game_buttons_ev_enable_read();
    unsigned int last_state = ~game_buttons_in_read(); //Uno es presionado
    
    button_debounce();//Espero

    unsigned int state = ~game_buttons_in_read(); 
    if (state == last_state){//Verifico estabilidad
        buttons = buttons & state; //Selecciono solo los que estan presionados, por lo que la interrupcion es por nivel.
        while(buttons){
            unsigned int button = __builtin_ctz(buttons);
            switch (button) {
                case GAME_BUTTONS_A: 
                    puts("Bt-A");
                    break;
                case GAME_BUTTONS_B:
                    puts("Bt-B");
                    break;
                case GAME_BUTTONS_START: 
                    puts("Bt-START");
                    break;
                case GAME_BUTTONS_SELECT: 
                    puts("Bt-SELECT");
                    break;
                case GAME_BUTTONS_RIGHT:                    
                    puts("Bt-RIGHT");
                    break;
                case GAME_BUTTONS_UP: 
                    puts("Bt-UP");
                    break;
                case GAME_BUTTONS_DOWN: 
                    puts("Bt-DOWN");
                    break;
                case GAME_BUTTONS_LEFT:
                    puts("Bt-LEFT");
                    break;
            }
            buttons &= buttons -1;
        }
    }
    game_buttons_ev_pending_write(0xFF);

};

void game_buttons_init(void) {
    game_buttons_mode_write(GAME_BUTTONS_MODE_CHANGE);
    game_buttons_ev_enable_write(GAME_BUTTONS_ALL_ENABLE);
    if (irq_attach) irq_attach(GAME_BUTTONS_INTERRUPT,game_buttons_isr);
    irq_setmask(irq_getmask() | (1 << GAME_BUTTONS_INTERRUPT));
};
//unsigned int get_game_button(unsigned int n_button);
//int attach_isr_to_button(unsigned int n_button, isr_t isr);


//TODO
#endif
