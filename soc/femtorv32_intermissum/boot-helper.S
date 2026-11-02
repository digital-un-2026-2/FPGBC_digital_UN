// Parte de https://github.com/enjoy-digital/litex/tree/master/litex/soc/cores/cpu/femtorv

	.section .text, "ax", @progbits
	.global boot_helper
boot_helper:
	jr x13
