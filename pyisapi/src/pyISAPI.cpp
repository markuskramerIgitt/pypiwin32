/*
 ======================================================================
 Copyright 2002-2003 by Blackdog Software Pty Ltd.

                         All Rights Reserved

 Permission to use, copy, modify, and distribute this software and
 its documentation for any purpose and without fee is hereby
 granted, provided that the above copyright notice appear in all
 copies and that both that copyright notice and this permission
 notice appear in supporting documentation, and that the name of 
 Blackdog Software not be used in advertising or publicity pertaining to
 distribution of the software without specific, written prior
 permission.

 BLACKDOG SOFTWARE DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN
 NO EVENT SHALL BLACKDOG SOFTWARE BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
 OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 ======================================================================
 */

// PYISAPI.CPP - Implementation file for your Internet Server
//    Python ISAPI Extension

#include "stdafx.h"
#include "pyISAPI.h"
#include "pyExtensionObjects.h"
#include "pyFilterObjects.h"

static const char *name_ext_factory = "__ExtensionFactory__";
static const char *name_ext_init = "GetExtensionVersion";
static const char *name_ext_do = "HttpExtensionProc";
static const char *name_ext_term = "TerminateExtension";

static const char *name_filter_factory = "__FilterFactory__";
static const char *name_filter_init = "GetFilterVersion";
static const char *name_filter_do = "HttpFilterProc";
static const char *name_filter_term = "TerminateFilter";

static CPythonEngine pyEngine;
static CPythonHandler filterHandler;
static CPythonHandler extensionHandler;


bool g_IsFrozen = false;
char g_CallbackModuleName[_MAX_PATH + _MAX_FNAME] = "";

#define TRACE OutputDebugString

// This is an entry point for py2exe.
void WINAPI PyISAPISetOptions(const char *modname, BOOL is_frozen)
{
	strncpy(g_CallbackModuleName, modname,
			sizeof(g_CallbackModuleName)/sizeof(g_CallbackModuleName[0]));
	// cast BOOL->bool without compiler warning!
	g_IsFrozen = is_frozen ? TRUE : FALSE;
}

BOOL WINAPI GetExtensionVersion(HSE_VERSION_INFO *pVer)
{
	pVer->dwExtensionVersion = MAKELONG( HSE_VERSION_MINOR, HSE_VERSION_MAJOR );
	// ensure our handler ready to go
	if (!extensionHandler.Init(&pyEngine, name_ext_factory,
							   name_ext_init, name_ext_do, name_ext_term)) {
		// already have reported any errors to Python.
		TRACE("Unable to load Python handler");
		return false;
	}
	PyObject *resultobject = NULL;
	bool bRetStatus = true;
	PyGILState_STATE state = PyGILState_Ensure();

	// create the Python object
	PyVERSION_INFO *pyVO = new PyVERSION_INFO(pVer);
	resultobject = extensionHandler.Callback(HANDLER_INIT, "N", pyVO);
	if (! resultobject) {
		ExtensionError(NULL, "Extension version function failed!");
		bRetStatus = false;
	} else {
		if (resultobject == Py_None)
			bRetStatus = TRUE;
		else if (PyInt_Check(resultobject))
			bRetStatus = PyInt_AsLong(resultobject) ? true : false;
		else {
			ExtensionError(NULL, "Filter init should return an int, or None");
			bRetStatus = FALSE;
		}
	}
	Py_XDECREF(resultobject);
	PyGILState_Release(state);
	return bRetStatus;
}

DWORD WINAPI HttpExtensionProc(EXTENSION_CONTROL_BLOCK *pECB)
{
	DWORD result;
	PyGILState_STATE state = PyGILState_Ensure();
	CControlBlock * pcb = new CControlBlock(pECB);
	PyECB *pyECB = new PyECB(pcb);
	PyObject *resultobject = extensionHandler.Callback(HANDLER_DO, "N", pyECB);
	if (! resultobject) {
		ExtensionError(pcb, "HttpExtensionProc function failed!");
		result = HSE_STATUS_ERROR;
	} else {
		if (PyInt_Check(resultobject))
			result = PyInt_AsLong(resultobject);
		else {
			ExtensionError(pcb, "HttpExtensionProc should return an int");
			result = HSE_STATUS_ERROR;
		}
	}
	Py_XDECREF(resultobject);
	PyGILState_Release(state);
	return result;
}

BOOL WINAPI TerminateExtension(DWORD dwFlags)
{
	// extension is being terminated
	BOOL bRetStatus;
	PyGILState_STATE state = PyGILState_Ensure();
	PyObject *resultobject = extensionHandler.Callback(HANDLER_TERM, "i", dwFlags);
	if (! resultobject) {
		ExtensionError(NULL, "Extension term function failed!");
		bRetStatus = false;
	} else {
		if (resultobject == Py_None)
			bRetStatus = TRUE;
		else if (PyInt_Check(resultobject))
			bRetStatus = PyInt_AsLong(resultobject) ? true : false;
		else {
			ExtensionError(NULL, "Extension term should return an int, or None");
			bRetStatus = FALSE;
		}
	}
	Py_XDECREF(resultobject);
	PyGILState_Release(state);
	extensionHandler.Term();
	return bRetStatus;
}

BOOL WINAPI GetFilterVersion(HTTP_FILTER_VERSION *pVer)
{
	pVer->dwFilterVersion = HTTP_FILTER_REVISION;
	// ensure our handler ready to go
	if (!filterHandler.Init(&pyEngine, name_filter_factory,
	                        name_filter_init, name_filter_do, name_filter_term))
		// error already imported.
		return FALSE;

	PyGILState_STATE state = PyGILState_Ensure();
	PyFILTER_VERSION *pyFV = new PyFILTER_VERSION(pVer);
	PyObject *resultobject = filterHandler.Callback(HANDLER_INIT, "N", pyFV);
	BOOL bRetStatus;
	if (! resultobject) {
		FilterError(NULL, "Filter version function failed!");
		bRetStatus = false;
	} else {
		if (resultobject == Py_None)
			bRetStatus = TRUE;
		else if (PyInt_Check(resultobject))
			bRetStatus = PyInt_AsLong(resultobject) ? true : false;
		else {
			FilterError(NULL, "Filter init should return an int, or None");
			bRetStatus = FALSE;
		}
	}
	Py_XDECREF(resultobject);
	PyGILState_Release(state);
	return bRetStatus;
}

DWORD WINAPI HttpFilterProc(HTTP_FILTER_CONTEXT *phfc, DWORD NotificationType, VOID *pvData)
{
	DWORD action;
	PyGILState_STATE state = PyGILState_Ensure();

	PyObject *resultobject = NULL;

	// create the Python object
	CFilterContext fc(phfc, NotificationType, pvData);
	PyHFC *pyHFC = new PyHFC(&fc);
	resultobject = filterHandler.Callback(HANDLER_DO, "O", pyHFC);
	if (! resultobject) {
		FilterError(&fc, "Filter function failed!");
		action = SF_STATUS_REQ_ERROR;
	} else {
		DWORD action;
		if (resultobject == Py_None)
			action = SF_STATUS_REQ_NEXT_NOTIFICATION;
		else if (PyInt_Check(resultobject))
			action = PyInt_AsLong(resultobject);
		else {
			FilterError(&fc, "Filter should return an int, or None");
			action = SF_STATUS_REQ_ERROR;
		}
	}
	pyHFC->Reset();
	Py_DECREF(pyHFC);
	Py_XDECREF(resultobject);
	PyGILState_Release(state);
	return action;
}

BOOL WINAPI TerminateFilter(DWORD status)
{
	BOOL bRetStatus;
	PyGILState_STATE state = PyGILState_Ensure();
	PyObject *resultobject = filterHandler.Callback(HANDLER_TERM, "i", status);
	if (! resultobject) {
		FilterError(NULL, "Filter version function failed!");
		bRetStatus = false;
	} else {
		if (resultobject == Py_None)
			bRetStatus = TRUE;
		else if (PyInt_Check(resultobject))
			bRetStatus = PyInt_AsLong(resultobject) ? true : false;
		else {
			FilterError(NULL, "Filter term should return an int, or None");
			bRetStatus = FALSE;
		}
	}
	Py_XDECREF(resultobject);
	PyGILState_Release(state);
	// filter is being terminated
	filterHandler.Term();
	return bRetStatus;
}

///////////////////////////////////////////////////////////////////////
// If your extension will not use MFC, you'll need this code to make
// sure the extension objects can find the resource handle for the
// module.  If you convert your extension to not be dependent on MFC,
// remove the comments arounn the following AfxGetResourceHandle()
// and DllMain() functions, as well as the g_hInstance global.

HINSTANCE g_hInstance = 0;

BOOL WINAPI DllMain(HINSTANCE hInst, ULONG ulReason,
					LPVOID lpReserved)
{
	if (ulReason == DLL_PROCESS_ATTACH)
	{
		g_hInstance = hInst;
	}

	return TRUE;
}

