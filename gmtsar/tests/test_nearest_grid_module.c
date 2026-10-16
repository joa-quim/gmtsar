#include "gmt.h"
#include "../gmtsar_commands.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

static uint64_t node(const struct GMT_GRID *G, uint64_t row, uint64_t col) {
	return (row + G->header->pad[2]) * G->header->mx + col + G->header->pad[0];
}

int main(void) {
	double wesn[4] = {0.0, 2.0, 0.0, 2.0}, inc[2] = {1.0, 1.0};
	struct GMT_GRID *input = NULL, *output = NULL;
	char input_name[GMT_VF_LEN] = {0}, output_name[GMT_VF_LEN] = {0};
	char output_arg[GMT_VF_LEN + 3], *args[2];
	const char *keys;
	void *API = GMT_Create_Session("nearest_grid API test", 2U, 0U, NULL);
	int status = 1;
	uint64_t row, col;

	if (API == NULL) return 1;
	keys = gmtsar_module_keys(API, "nearest_grid");
	if (keys == NULL || strcmp(keys, "<G{,GG}")) goto cleanup;
	input = GMT_Create_Data(API, GMT_IS_GRID, GMT_IS_SURFACE,
		GMT_CONTAINER_AND_DATA, NULL, wesn, inc, GMT_GRID_NODE_REG, 0, NULL);
	if (input == NULL) goto cleanup;
	for (row = 0; row < input->header->n_rows; ++row)
		for (col = 0; col < input->header->n_columns; ++col)
			input->data[node(input, row, col)] = (gmt_grdfloat)(row * 10 + col);
	input->data[node(input, 1, 1)] = (gmt_grdfloat)NAN;
	if (GMT_Open_VirtualFile(API, GMT_IS_GRID, GMT_IS_SURFACE,
		GMT_IN | GMT_IS_REFERENCE, input, input_name) != GMT_NOERROR) goto cleanup;
	if (GMT_Open_VirtualFile(API, GMT_IS_GRID, GMT_IS_SURFACE,
		GMT_OUT | GMT_IS_REFERENCE, NULL, output_name) != GMT_NOERROR) goto cleanup;
	args[0] = input_name;
	snprintf(output_arg, sizeof(output_arg), "-G%s", output_name);
	args[1] = output_arg;
	if (GMT_nearest_grid(API, 2, args) != GMT_NOERROR) goto cleanup;
	output = GMT_Read_VirtualFile(API, output_name);
	if (output == NULL || isnan(output->data[node(output, 1, 1)])) goto cleanup;
	status = 0;

cleanup:
	GMT_Close_VirtualFile(API, input_name);
	GMT_Close_VirtualFile(API, output_name);
	if (GMT_Destroy_Session(API) != GMT_NOERROR) status = 1;
	if (status) fprintf(stderr, "nearest_grid virtual-grid module test failed\n");
	return status;
}
