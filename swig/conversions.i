/*
 *    This file is part of acados.
 *
 *    acados is free software; you can redistribute it and/or
 *    modify it under the terms of the GNU Lesser General Public
 *    License as published by the Free Software Foundation; either
 *    version 3 of the License, or (at your option) any later version.
 *
 *    acados is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *    Lesser General Public License for more details.
 *
 *    You should have received a copy of the GNU Lesser General Public
 *    License along with acados; if not, write to the Free Software Foundation,
 *    Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#if defined(SWIGPYTHON)
%include "numpy.i"
%fragment("NumPy_Fragments");
%init %{
import_array();
%}
#endif

%{
#include "swig/conversions.h"

#include <algorithm>
#include <stdexcept>
#include <typeinfo>

#if defined(SWIGMATLAB)
mxClassID get_numeric_type() {
    if (typeid(T) == typeid(real_t))
        return mxDOUBLE_CLASS;
    else if (typeid(T) == typeid(int_t))
        return mxDOUBLE_CLASS;
    throw std::invalid_argument("Matrix can only have integer or floating point entries");
    return 0;
}
#elif defined(SWIGPYTHON)
template<typename T>
int get_numeric_type() {
    if (typeid(T) == typeid(int_t))
        return NPY_INT32;
    else if (typeid(T) == typeid(long))
        return NPY_INT64;
    else if (typeid(T) == typeid(real_t))
        return NPY_DOUBLE;
    throw std::invalid_argument("Matrix can only have integer or floating point entries");
    return 0;
}
#endif

bool is_integer(const LangObject *input) {
#if defined(SWIGMATLAB)
    if (!mxIsScalar(input) || !mxIsNumeric(input))
        return false;
    return true;
#elif defined(SWIGPYTHON)
    if (!PyLong_Check((PyObject *) input))
        return false;
    return true;
#endif
}

int_t int_from(const LangObject *scalar) {
#if defined(SWIGMATLAB)
    return (int_t) mxGetScalar(scalar);
#elif defined(SWIGPYTHON)
    return (int_t) PyLong_AsLong((PyObject *) scalar);
#endif
}

bool is_matrix(const LangObject *input) {
#if defined(SWIGMATLAB)
    if (!mxIsNumeric(input))
        return false;
    mwSize nb_dims = mxGetNumberOfDimensions(input);
    if (nb_dims != 2)
        return false;
    return true;
#elif defined(SWIGPYTHON)
    if (!PyArray_Check(input))
        return false;
    int nb_dims = PyArray_NDIM((PyArrayObject *) input);
    if (nb_dims < 1 || nb_dims > 2)
        return false;
    return true;
#endif
}

bool is_matrix(const LangObject *input, const int_t nb_rows, const int_t nb_columns) {
    if (!is_matrix(input))
        return false;
#if defined(SWIGMATLAB)
    mwSize *dims = mxGetDimensions(input);
    if (dims[0] != nb_rows || dims[1] != nb_columns)
        return false;
    return true;
#elif defined(SWIGPYTHON)
    int nb_dims = PyArray_NDIM((PyArrayObject *) input);
    npy_intp *dims = PyArray_DIMS((PyArrayObject *) input);
    if (dims[0] != nb_rows)
        return false;
    if (nb_dims == 1) {
        if (nb_columns != 1)
            return false;
    } else {
        if (dims[1] != nb_columns)
            return false;
    }
    return true;
#endif
}

template<typename T>
LangObject *new_matrix(const int_t *dims, const T *data) {
    int_t nb_rows = dims[0];
    int_t nb_cols = dims[1];
#if defined(SWIGMATLAB)
    mxArray *matrix = mxCreateNumericMatrix(nb_rows, nb_cols, get_numeric_type<T>(), mxREAL);
    mxArray *new_array = mxCalloc(nb_rows*nb_cols, sizeof(T));
    for (int_t i = 0; i < nb_rows*nb_cols; i++)
        intermediate[i] = data[i];
    mxSetData(matrix, new_array);
    return matrix;
#elif defined(SWIGPYTHON)
    PyObject *array;
    if (nb_cols == 1) {
        npy_intp npy_dims[1] = {nb_rows};
        array = PyArray_NewFromDataF(1, npy_dims, get_numeric_type<T>(), (void *) data);
    } else {
        npy_intp npy_dims[2] = {nb_rows, nb_cols};
        array = PyArray_NewFromDataF(2, npy_dims, get_numeric_type<T>(), (void *) data);
    }
    PyObject *matrix = PyArray_NewCopy((PyArrayObject *) array, NPY_FORTRANORDER);
    if (matrix == NULL)
        throw std::runtime_error("Something went wrong while copying array");
    return matrix;
#endif
}

bool is_sequence(const LangObject *object) {
#if defined(SWIGMATLAB)
    if (!mxIsCell(object))
        return false;
#elif defined(SWIGPYTHON)
    if (!PyList_Check((PyObject *) object))
        return false;
#endif
    return true;
}

bool is_sequence(const LangObject *input, int_t expected_length) {
    if (!is_sequence(input))
        return false;
#if defined(SWIGMATLAB)
    int_t length_of_sequence = mxGetNumberOfElements(input);
#elif defined(SWIGPYTHON)
    int_t length_of_sequence = PyList_Size((PyObject *) input);
#endif
    if (length_of_sequence != expected_length)
        return false;
    return true;
}

LangObject *from(const LangObject *sequence, int_t index) {
#if defined(SWIGMATLAB)
    return mxGetCell(sequence, index);
#elif defined(SWIGPYTHON)
    return PyList_GetItem((PyObject *) sequence, index);
#endif
}

LangObject *new_sequence(const int_t length) {
#if defined(SWIGMATLAB)
    const mwSize dims[1] = {length};
    return mxCreateCellArray(1, dims);
#elif defined(SWIGPYTHON)
    return PyList_New(length);
#endif
}

template <typename T>
LangObject *new_sequence_from(const T *array, const int_t length) {
    LangObject *sequence = new_sequence(length);
    for (int_t index = 0; index < length; index++) {
        if (typeid(T) == typeid(int_t))
            write_int_to(sequence, index, array[index]);
        else if (typeid(T) == typeid(real_t))
            write_real_to(sequence, index, array[index]);
    }
    return sequence;
}

void fill_int_array_from(const LangObject *sequence, int_t *array, const int_t length) {
    for (int_t index = 0; index < length; index++) {
        LangObject *item = from(sequence, index);
        if (!is_integer(item)) {
            char err_msg[256];
            snprintf(err_msg, sizeof(err_msg), "Input %s elements must be scalars",
                LANG_SEQUENCE_NAME);
            throw std::invalid_argument(err_msg);
        }
        array[index] = int_from(item);
    }
}

bool is_map(const LangObject *object) {
#if defined(SWIGMATLAB)
    if (!mxIsStruct(object))
        return false;
#elif defined(SWIGPYTHON)
    if (!PyDict_Check(object))
        return false;
#endif
    return true;
}

bool has(const LangObject *map, const char *key) {
#if defined(SWIGMATLAB)
    if (mxGetField(map, 0, key) == NULL)
        return false;
#elif defined(SWIGPYTHON)
    if (PyDict_GetItemString((PyObject *) map, key) == NULL)
        return false;
#endif
    return true;
}

LangObject *from(const LangObject *map, const char *key) {
    if (!has(map, key)) {
        char err_msg[256];
        snprintf(err_msg, sizeof(err_msg), "Input %s has no key %s", LANG_MAP_NAME, key);
        throw std::invalid_argument(err_msg);
    }
#if defined(SWIGMATLAB)
    return mxGetField(map, 0, key);
#elif defined(SWIGPYTHON)
    return PyDict_GetItemString((PyObject *) map, key);
#endif
}

int_t int_from(const LangObject *map, const char *key) {
#if defined(SWIGMATLAB)
    mxArray *value_ptr = mxGetField(map, 0, key);
    return (int_t) mxGetScalar(value_ptr);
#elif defined(SWIGPYTHON)
    return (int_t) PyLong_AsLong(PyDict_GetItemString((PyObject *) map, key));
#endif
}

void fill_array_from(const LangObject *input, int_t *array, const int_t length) {
    if (is_integer(input)) {
        int_t number = int_from(input);
        for (int_t i = 0; i < length; i++)
            array[i] = number;
    } else if (is_sequence(input, length)) {
        fill_int_array_from(input, array, length);
    } else {
        char err_msg[256];
        snprintf(err_msg, sizeof(err_msg), \
            "Expected scalar or %s of length %d", LANG_SEQUENCE_NAME, length);
        throw std::invalid_argument(err_msg);
    }
}

void fill_array_from(const LangObject *map, const char *key, int_t *array, int_t array_length) {
    if (!has(map, key)) {
        memset(array, 0, array_length*sizeof(*array));
    } else {
        LangObject *item = from(map, key);
        fill_array_from(item, array, array_length);
    }
}

void to(LangObject *sequence, const int_t index, LangObject *item) {
#if defined(SWIGMATLAB)
    mxSetCell(sequence, index, item);
#elif defined(SWIGPYTHON)
    PyList_SetItem(sequence, index, item);
#endif
}

void write_int_to(LangObject *sequence, const int_t index, const int_t number) {
#if defined(SWIGMATLAB)
    mxArray *scalar = mxCreateNumericMatrix(1, 1, mxINT32_CLASS, mxREAL);
    to(sequence, index, scalar);
#elif defined(SWIGPYTHON)
    to(sequence, index, PyLong_FromLong((long) number));
#endif
}

void write_real_to(LangObject *sequence, const int_t index, const real_t number) {
#if defined(SWIGMATLAB)
    mxArray *scalar = mxCreateDoubleScalar(number);
    to(sequence, index, scalar);
#elif defined(SWIGPYTHON)
    to(sequence, index, PyFloat_FromDouble((double) number));
#endif
}

template<typename T>
LangObject *new_sequence_from(const T **data, const int_t length,
    const int_t *nb_rows, const int_t *nb_columns) {

    LangObject *sequence = new_sequence(length);
    for (int_t index = 0; index < length; index++) {
        int_t dims[2] = {nb_rows[index], nb_columns[index]};
        LangObject *item = new_matrix<T>(dims, data[index]);
        to(sequence, index, item);
    }
    return sequence;
}

template<typename T>
LangObject *new_sequence_from(const T **data, const int_t length,
    const int_t *nb_elems) {

    int_t nb_columns[length];
    for (int_t i = 0; i < length; i++)
        nb_columns[i] = 1;
    return new_sequence_from(data, length, nb_elems, nb_columns);
}

bool dimensions_match(const LangObject *matrix, const int_t *nb_rows, const int_t *nb_cols,
    const int_t length) {

    int_t rows = nb_rows[0];
    int_t cols = nb_cols[0];
    for (int_t i = 1; i < length; i++) {
        if (nb_rows[i] != rows || nb_cols[i] != cols) {
            throw std::invalid_argument("If just given one matrix, dimensions for all stages "
                "must be equal");
            return false;
        }
    }
    if (!is_matrix(matrix, rows, cols)) {
        throw std::invalid_argument("Input matrix has wrong dimensions");
        return false;
    }
    return true;
}

template<typename T>
void copy_from(const LangObject *matrix, T *data, const int_t nb_elems) {
#if defined(SWIGMATLAB)
    if (!mxIsDouble(matrix))
        SWIG_Error(SWIG_ValueError, "Only matrices with double precision numbers allowed");
    double *matrix_data = mxGetData(matrix);
    std::copy(matrix_data, matrix_data + nb_elems, data);
#elif defined(SWIGPYTHON)
    if (PyArray_TYPE((PyArrayObject *) matrix) == get_numeric_type<int_t>()) {
        int_t *matrix_data = (int_t *) PyArray_DATA((PyArrayObject *) matrix);
        std::copy(matrix_data, matrix_data + nb_elems, data);
    } else if (PyArray_TYPE((PyArrayObject *) matrix) == get_numeric_type<long>()) {
        long *matrix_data = (long *) PyArray_DATA((PyArrayObject *) matrix);
        std::copy(matrix_data, matrix_data + nb_elems, data);
    } else if (PyArray_TYPE((PyArrayObject *) matrix) == get_numeric_type<real_t>()) {
        real_t *matrix_data = (real_t *) PyArray_DATA((PyArrayObject *) matrix);
        std::copy(matrix_data, matrix_data + nb_elems, data);
    } else {
        throw std::invalid_argument("Only matrices with integer or double "
            "precision numbers allowed");
    }
#endif
}

template<typename T>
void fill_array_from(const LangObject *input, T **array,
    const int_t length, const int_t *nb_rows, const int_t *nb_columns) {

    if (is_matrix(input) && dimensions_match(input, nb_rows, nb_columns, length)) {
        int_t nb_elems = nb_rows[0]*nb_columns[0];
        for (int_t index = 0; index < length; index++) {
            copy_from(input, array[index], nb_elems);
        }
    } else if (is_sequence(input, length)) {
        for (int_t index = 0; index < length; index++) {
            LangObject *item = from(input, index);
            if (is_matrix(item, nb_rows[index], nb_columns[index]))
                copy_from(item, array[index], nb_rows[index]*nb_columns[index]);
        }
    } else {
        char err_msg[256];
        snprintf(err_msg, sizeof(err_msg),
            "Expected %s or %s as input", LANG_SEQUENCE_NAME, LANG_MATRIX_NAME);
        throw std::invalid_argument(err_msg);
    }
}

template<typename T>
void fill_array_from(const LangObject *input, T **array, const int_t length,
    const int_t *nb_elems) {

    int_t nb_columns[length];
    for (int_t i = 0; i < length; i++)
        nb_columns[i] = 1;
    fill_array_from(input, array, length, nb_elems, nb_columns);
}

%}