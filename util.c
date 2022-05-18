#include "envrnbld.h"
#include "util.h"
void SetSymbolUDFValue(Environment *env, UDFValue *out, char *l) {
	out->lexemeValue = CreateSymbol(env,l);
}

void UserFunctions(Environment *e) {
	AddUDF(e,"new-uuid","y",0,0,NULL,NewUuid,"NewUuid",NULL);
}

