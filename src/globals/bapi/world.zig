pub const SIZE_ZLEVEL_X = 255;
pub const SIZE_ZLEVEL_Y = 255;
pub const SIZE_Z = 9;

pub const SIZE_X = SIZE_ZLEVEL_X * @trunc(@sqrt(SIZE_Z));
pub const SIZE_Y = SIZE_ZLEVEL_Y * @trunc(@sqrt(SIZE_Z));
pub const SIZE_TOTAL = SIZE_X * SIZE_Y;

pub const Z_BORDER_SIZE_X = 10;
pub const Z_BORDER_SIZE_Y = 7;

pub const SIZE_X_ADJUSTED_FOR_BORDER = SIZE_X - @trunc(@sqrt(SIZE_Z)) * Z_BORDER_SIZE_X;
pub const SIZE_Y_ADJUSTED_FOR_BORDER = SIZE_Y - @trunc(@sqrt(SIZE_Z)) * Z_BORDER_SIZE_Y;
