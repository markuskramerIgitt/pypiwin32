/* File : pywin32.i 

The start of an interface file for SWIG and the Win32 Python extensions.

Much of the support in here requires the extension linking with
"PyWinTypes.lib", as core Win32 Python object support lives in PyWinTypes.dll

Not complete, but a pretty good start!

Maintained by MHammond@skippinet.com.au, and my version is almost guaranteed later
than the one you are looking at - please forward any changes on, and I'll send you
a new integrated one!
*/

typedef char * LPCSTR;
%apply char * {LPCSTR};

typedef const char * LPCTSTR;
%apply const char * {LPCTSTR};

typedef unsigned short WORD;
%apply unsigned short {WORD};

typedef unsigned long DWORD;
%apply unsigned long {DWORD};

typedef int BOOL;
%apply int {BOOL};

typedef long LONG;
%apply long {LONG};

typedef unsigned long ULONG;
%apply unsigned long {ULONG};


%{
#include "windows.h"
#include "winbase.h"
#include "PyWinTypes.h"
#include "tchar.h"
%}

// Override the SWIG default for this.
%typemap(python,out) PyObject *{
	if ($source==NULL) return NULL; // get out now!
	$target = $source;
}

//
// Map API functions that return BOOL to
// functions that return None, but raise exceptions.
// These functions must set the win32 LastError.
%typedef BOOL BOOLAPI

%typemap(python,out) BOOLAPI {
	$target = Py_None;
	Py_INCREF(Py_None);
}

%typemap(python,except) BOOLAPI {
      Py_BEGIN_ALLOW_THREADS
      $function
      Py_END_ALLOW_THREADS
      if (!$source)  {
           $cleanup
           return PyWin_SetAPIError("$name");
      }
}

%typedef DWORD DWORDAPI

%typemap(python,out) DWORDAPI {
	$target = Py_None;
	Py_INCREF(Py_None);
}

%typemap(python,except) DWORDAPI {
      Py_BEGIN_ALLOW_THREADS
      $function
      Py_END_ALLOW_THREADS
      if ($source!=0)  {
           $cleanup
           return PyWin_SetAPIError("$name", $source);
      }
}

// String and UniCode support
%typemap(python,in) char *inNullString {
	if ($source==Py_None) {
		$target = NULL;
	} else if (PyString_Check($source)) {
		$target = PyString_AsString($source);
	} else {
		PyErr_SetString(PyExc_TypeError, "Argument must be None or a string");
		return NULL;
	}
}

%typemap(python,in) TCHAR * {
	if (!PyWinObject_AsTCHAR($source, &$target, FALSE))
		return NULL;
}

%typemap(python,arginit) TCHAR *,OLECHAR *, WCHAR *
{
	$target = NULL;
}

%typemap(python,in) TCHAR *inNullString{
	if (!PyWinObject_AsTCHAR($source, &$target, TRUE))
		return NULL;
}
%typemap(python,in) TCHAR *INPUT_NULLOK = TCHAR *inNullString;

%typemap(python,freearg) TCHAR *{
	PyWinObject_FreeTCHAR($source);
}

// Delete this!
%typemap(python,freearg) TCHAR *inNullWideString {
	PyWinObject_FreeTCHAR($source);
}

%typemap(python,freearg) TCHAR *inNullString {
	PyWinObject_FreeTCHAR($source);
}


%typemap(python,in) OLECHAR *, WCHAR *{
	// Wide string code!
	if (!PyWinObject_AsBstr($source, &$target, FALSE))
		return NULL;
}

%typemap(python,in) OLECHAR *inNullWideString,
                    WCHAR *inNullWideString {
	// Wide string code!
	if (!PyWinObject_AsBstr($source, &$target, TRUE))
		return NULL;
}

%typemap(python,freearg) OLECHAR *, WCHAR *{
	// Wide string cleanup
	SysFreeString($source);
}

// An object that can be used in place of a BSTR, but guarantees
// cleanup of the string.
%typemap(python,in) PyWin_AutoFreeBstr inWideString {
	// Auto-free Wide string code!
	if (!PyWinObject_AsAutoFreeBstr($source, &$target, FALSE))
		return NULL;
}

%typemap(python,in) PyWin_AutoFreeBstr inNullWideString {
	// Auto-free Wide string code!
	if (!PyWinObject_AsAutoFreeBstr($source, &$target, TRUE))
		return NULL;
}

%typemap(python,in) OVERLAPPED *
{
	if (!PyWinObject_AsOVERLAPPED($source, &$target, TRUE))
		return NULL;
}
%typemap(python,argout) OVERLAPPED *OUTPUT {
    PyObject *o;
    o = PyWinObject_FromOVERLAPPED(*$source);
    if (!$target) {
      $target = o;
    } else if ($target == Py_None) {
      Py_DECREF(Py_None);
      $target = o;
    } else {
      if (!PyList_Check($target)) {
	PyObject *o2 = $target;
	$target = PyList_New(0);
	PyList_Append($target,o2);
	Py_XDECREF(o2);
      }
      PyList_Append($target,o);
      Py_XDECREF(o);
    }
}
%typemap(python,ignore) OVERLAPPED *OUTPUT(OVERLAPPED temp)
{
  $target = &temp;
}

%typemap(python,argout) OVERLAPPED **OUTPUT {
    PyObject *o;
    o = PyWinObject_FromOVERLAPPED(*$source);
    if (!$target) {
      $target = o;
    } else if ($target == Py_None) {
      Py_DECREF(Py_None);
      $target = o;
    } else {
      if (!PyList_Check($target)) {
	PyObject *o2 = $target;
	$target = PyList_New(0);
	PyList_Append($target,o2);
	Py_XDECREF(o2);
      }
      PyList_Append($target,o);
      Py_XDECREF(o);
    }
}
%typemap(python,ignore) OVERLAPPED **OUTPUT(OVERLAPPED *temp)
{
  $target = &temp;
}



%typemap(python,in) SECURITY_ATTRIBUTES *{
	if (!PyWinObject_AsSECURITY_ATTRIBUTES($source, &$target))
		return NULL;
}
//---------------------------------------------------------------------------
//
// HANDLE support
//
// PyHANDLE will use a PyHANDLE object.
// PyHKEY will use a PyHKEY object
// HANDLE will use an integer.
//---------------------------------------------------------------------------
//typedef void *HANDLE;

%typemap(python,ignore) HANDLE *OUTPUT(HANDLE temp)
{
  $target = &temp;
}

%typemap(python,except) PyHANDLE {
      Py_BEGIN_ALLOW_THREADS
      $function
      Py_END_ALLOW_THREADS
      if ($source==0 || $source==INVALID_HANDLE_VALUE)  {
           $cleanup
           return PyWin_SetAPIError("$name");
      }
}

%typemap(python,except) PyHKEY {
      Py_BEGIN_ALLOW_THREADS
      $function
      Py_END_ALLOW_THREADS
      if ($source==0 || $source==INVALID_HANDLE_VALUE)  {
           $cleanup
           return PyWin_SetAPIError("$name");
      }
}

%typemap(python,except) HANDLE {
      Py_BEGIN_ALLOW_THREADS
      $function
      Py_END_ALLOW_THREADS
      if ($source==0 || $source==INVALID_HANDLE_VALUE)  {
           $cleanup
           return PyWin_SetAPIError("$name");
      }
}
%apply long {HANDLE};
typedef long HANDLE;

typedef HANDLE PyHANDLE;
%{
#define PyHANDLE HANDLE // Use a #define so we can undef it later if we need the true defn.
//typedef HANDLE PyHKEY;
%}

%typemap(python,in) HANDLE {
	if (!PyWinObject_AsHANDLE($source, &$target, TRUE))
		return NULL;
}

%typemap(python,in) PyHANDLE {
	if (!PyWinObject_AsHANDLE($source, &$target, FALSE))
		return NULL;
}
%typemap(python,in) PyHKEY {
	if (!PyWinObject_AsHKEY($source, &$target, FALSE))
		return NULL;
}

%typemap(python,in) PyHANDLE INPUT_NULLOK {
	if (!PyWinObject_AsHANDLE($source, &$target, TRUE))
		return NULL;
}
%typemap(python,in) PyHKEY INPUT_NULLOK {
	if (!PyWinObject_AsHKEY($source, &$target, TRUE))
		return NULL;
}

%typemap(python,ignore) PyHANDLE *OUTPUT(HANDLE temp)
{
  $target = &temp;
}
%typemap(python,ignore) PyHKEY *OUTPUT(HKEY temp)
{
  $target = &temp;
}

%typemap(python,out) PyHANDLE {
  $target = PyWinObject_FromHANDLE($source);
}
%typemap(python,out) PyHKEY {
  $target = PyWinObject_FromHKEY($source);
}

%typemap(python,argout) PyHANDLE *OUTPUT {
    PyObject *o;
    o = PyWinObject_FromHANDLE(*$source);
    if (!$target) {
      $target = o;
    } else if ($target == Py_None) {
      Py_DECREF(Py_None);
      $target = o;
    } else {
      if (!PyList_Check($target)) {
	PyObject *o2 = $target;
	$target = PyList_New(0);
	PyList_Append($target,o2);
	Py_XDECREF(o2);
      }
      PyList_Append($target,o);
      Py_XDECREF(o);
    }
}
%typemap(python,argout) PyHKEY *OUTPUT {
    PyObject *o;
    o = PyWinObject_FromHKEY(*$source);
    if (!$target) {
      $target = o;
    } else if ($target == Py_None) {
      Py_DECREF(Py_None);
      $target = o;
    } else {
      if (!PyList_Check($target)) {
	PyObject *o2 = $target;
	$target = PyList_New(0);
	PyList_Append($target,o2);
	Py_XDECREF(o2);
      }
      PyList_Append($target,o);
      Py_XDECREF(o);
    }
}

//---------------------------------------------------------------------------
//
// LARGE_INTEGER support
//
//---------------------------------------------------------------------------
%typemap(python,in) LARGE_INTEGER {
	if (!PyWinObject_AsLARGE_INTEGER($source, &$target, FALSE))
		return NULL;
}
%typemap(python,in) ULARGE_INTEGER {
	if (!PyWinObject_AsULARGE_INTEGER($source, &$target, FALSE))
		return NULL;
}

%typemap(python,ignore) LARGE_INTEGER *OUTPUT(LARGE_INTEGER temp)
{
  $target = &temp;
}
%typemap(python,ignore) ULARGE_INTEGER *OUTPUT(ULARGE_INTEGER temp)
{
  $target = &temp;
}

%typemap(python,out) LARGE_INTEGER {
  $target = PyWinObject_FromLARGE_INTEGER($source);
}
%typemap(python,out) ULARGE_INTEGER {
  $target = PyWinObject_FromULARGE_INTEGER($source);
}

%typemap(python,argout) LARGE_INTEGER *OUTPUT {
    PyObject *o;
    o = PyWinObject_FromLARGE_INTEGER(*$source);
    if (!$target) {
      $target = o;
    } else if ($target == Py_None) {
      Py_DECREF(Py_None);
      $target = o;
    } else {
      if (!PyList_Check($target)) {
	PyObject *o2 = $target;
	$target = PyList_New(0);
	PyList_Append($target,o2);
	Py_XDECREF(o2);
      }
      PyList_Append($target,o);
      Py_XDECREF(o);
    }
}
%typemap(python,argout) ULARGE_INTEGER *OUTPUT {
    PyObject *o;
    o = PyWinObject_FromULARGE_INTEGER(*$source);
    if (!$target) {
      $target = o;
    } else if ($target == Py_None) {
      Py_DECREF(Py_None);
      $target = o;
    } else {
      if (!PyList_Check($target)) {
	PyObject *o2 = $target;
	$target = PyList_New(0);
	PyList_Append($target,o2);
	Py_XDECREF(o2);
      }
      PyList_Append($target,o);
      Py_XDECREF(o);
    }
}


//---------------------------------------------------------------------------
//
// TIME
//
//---------------------------------------------------------------------------
%typemap(python,in) FILETIME * {
	if (!PyWinObject_AsFILETIME($source, $target, FALSE))
		return NULL;
}
%typemap(python,ignore) FILETIME *(FILETIME temp)
{
  $target = &temp;
}

%typemap(python,out) FILETIME * {
  $target = PyWinObject_FromFILETIME($source);
}

%typemap(python,argout) FILETIME *OUTPUT {
    PyObject *o;
    o = PyWinObject_FromFILETIME(*$source);
    if (!$target) {
      $target = o;
    } else if ($target == Py_None) {
      Py_DECREF(Py_None);
      $target = o;
    } else {
      if (!PyList_Check($target)) {
	PyObject *o2 = $target;
	$target = PyList_New(0);
	PyList_Append($target,o2);
	Py_XDECREF(o2);
      }
      PyList_Append($target,o);
      Py_XDECREF(o);
    }
}

//---------------------------------------------------------------------------
//
// SOCKET support.
//
//---------------------------------------------------------------------------
%typemap(python,in) SOCKET *(SOCKET sockettemp)
{
	$target = &sockettemp;
	if (!PySocket_AsSOCKET($source, $target))
	{
		return NULL;
	}
}


//---------------------------------------------------------------------------
//
// Module initialization
//
//---------------------------------------------------------------------------
%init %{
#ifndef SWIG_PYTHONCOM
/* This code only valid if non COM SWIG builds */
#ifndef PYCOM_EXPORT
	 PyDict_SetItemString(d,"UNICODE", PyInt_FromLong(
#ifdef UNICODE
	1
#else
	0
#endif
	));
#endif
  PyWinGlobals_Ensure();
  PyDict_SetItemString(d, "error", PyWinExc_ApiError);
#endif SWIG_PYTHONCOM
%}

