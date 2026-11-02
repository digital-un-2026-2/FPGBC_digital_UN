#ifndef __GAME_BUTTONS_H
#define __GAME_BUTTONS_H

void game_buttons_init(void);
void game_buttons_isr(void);
unsigned int get_game_button(unsigned int n_button);
int attach_isr_to_button(unsigned int n_button, isr_t isr);
//TODO
#endif