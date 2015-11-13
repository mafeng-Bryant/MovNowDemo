//
//  MNDialogOtaUpgradeService.m
//  Movnow
//
//  Created by baoyx on 15/5/7.
//  Copyright (c) 2015年 HelloWorld. All rights reserved.
//

#import "MNDialogOtaUpgradeService.h"
#import "QBleClient.h"
#import "MNBleBaseService.h"
#import "MNFirmwareModel.h"
#import "MNDeviceBindingService.h"
#import <CoreBluetooth/CoreBluetooth.h>
typedef void (^UpgradeProgress)(int progress);  //升级进度
enum upgradeType
{
    I2C_TYPE,
    SPI_TYPE,
};

enum upgradeStaus
{
    SPOTA_WRITE_MEM_DEV,
    SPOTA_WRITE_GPIO_MAP,
    SPOTA_WRITE_PATH_LEN,
    SPOTA_WRITE_PATH_DATA,
    SPOTA_WRITE_SUCESS,
};

enum SPOTAR
{
    SPOTAR_SRV_STARTED = 0x01,
    SPOTAR_CMP_OK = 0x02,
    SPOTAR_SRV_EXIT = 0x03,
    SPOTAR_CRC_ERR = 0x04,
    SPOTAR_PATCH_LEN_ERR = 0x05,
    SPOTAR_EXT_MEM_WRITE_ERR = 0x06,
    SPOTAR_INT_MEM_ERR = 0x07,
    SPOTAR_INVAL_MEM_TYPE = 0x08,
    SPOTAR_APP_ERROR = 0x09,
    SPOTAR_IMG_STARTED = 0x10,
    SPOTAR_INVAL_IMG_BANK = 0x11,
    SPOTAR_INVAL_IMG_HDR = 0x12,
    SPOTAR_INVAL_IMG_SIZE = 0x13,
    SPOTAR_INVAL_PRODUCT_HDR = 0x14,
    SPOTAR_SAME_IMG_ERR = 0x15,
    SPOTAR_EXT_MEM_READ_ERR = 0x16,
};

static unsigned int crc32_tab[256] = {
    0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f,
    0xe963a535, 0x9e6495a3,	0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
    0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91, 0x1db71064, 0x6ab020f2,
    0xf3b97148, 0x84be41de,	0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
    0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,	0x14015c4f, 0x63066cd9,
    0xfa0f3d63, 0x8d080df5,	0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
    0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,	0x35b5a8fa, 0x42b2986c,
    0xdbbbc9d6, 0xacbcf940,	0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
    0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423,
    0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
    0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,	0x76dc4190, 0x01db7106,
    0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
    0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d,
    0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
    0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
    0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
    0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7,
    0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
    0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa,
    0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
    0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81,
    0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
    0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683, 0xe3630b12, 0x94643b84,
    0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
    0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
    0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
    0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5, 0xd6d6a3e8, 0xa1d1937e,
    0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
    0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55,
    0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
    0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe, 0xb2bd0b28,
    0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
    0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f,
    0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
    0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
    0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
    0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69,
    0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
    0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc,
    0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
    0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693,
    0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
    0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
};
@interface  MNDialogOtaUpgradeService()<MNBleBaseServiceDialogOtaUpgradeDelegate>

@end

@implementation MNDialogOtaUpgradeService
{
    int mI2cSclGpio;
    int mI2cSdaGpio;
    int mAddress;
    int mSpiCsGpio;
    int mSpiClkGpio;
    int mSpiMosiGpio;
    int mSpiMisoGpio;
    int mMemoryType;
    int mSpotaWriteStatus;
    BOOL readDataIsOver;
    int mBlockSize;
    int mBlockLength;
    int mBlockOffset;
    int mImageDataLength;
    int mChunckSize;
    int mChunckLength;
    int mChunckOffset;
    BOOL mIsLastChunk;
    BOOL mIsWriteLastLen;
    NSString *mSettings;
    
    Byte versionData[60000];            //保存固件数据
    qBleClient *client;
    MNBleBaseService *bleBaseService;
    
    CoreSuccess upgradeSucBlock_;
    CoreFailure upgradeFailureBlock_;
    UpgradeProgress upgradeProgressBlock_;
}

+(MNDialogOtaUpgradeService *)shareInstance
{
    static MNDialogOtaUpgradeService *simple;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        simple = [[MNDialogOtaUpgradeService alloc] init];
    });
    return simple;
}

-(instancetype)init
{
    if (self = [super init]) {
        client = [qBleClient sharedInstance];
        bleBaseService = [MNBleBaseService shareInstance];
        bleBaseService.dialogOtaUpgradeDelegate =self;
    }
    return self;
}

-(void)startDialogOtaUpgradeProgress:(void (^)(int))progress withSuccess:(CoreFailure)success withFailure:(CoreFailure)failure
{
    upgradeProgressBlock_ = [progress copy];
    upgradeSucBlock_ = [success copy];
    upgradeFailureBlock_ = [failure copy];
    
    [bleBaseService dialogOtaUpgradeWithSuccess:^(id result) {
        mI2cSclGpio=2;
        mI2cSdaGpio=3;
        mAddress=0x50;
        mSpiCsGpio=3;
        mSpiClkGpio = 0;
        mSpiMosiGpio = 6;
        mSpiMisoGpio = 5;
        mMemoryType = SPI_TYPE;
        mSpotaWriteStatus = -1;
        readDataIsOver = false;
        mBlockSize = 240;
        mBlockLength=0;
        mBlockOffset=0;
        mImageDataLength=0;
        mChunckSize=20;
        mChunckLength=0;
        mChunckOffset=0;
        mIsLastChunk=false;
        mIsWriteLastLen=false;
        mSettings=@"spi:clk=0x00,cs=0x03,mosi=0x06,miso=0x05,blocksize=240";
        [self checkSum];
        [self setSuotaSettings:mSettings];
        mIsWriteLastLen=false;
        [self suotaWriteMemDev];
    } withFailure:^(id reason) {
        failure(reason);
    }];
}

-(void)checkSum
{
    NSArray *btAddressArrayList=[self handlerBTaddress];
    
    
    NSLog(@"btAddressArrayList=%@",btAddressArrayList);
    mImageDataLength=[MNDeviceBindingService readLocalBLEVersionData:versionData];
    Byte  crc_code = 0;
    Byte crc_32bit[4];
    crc_32bit[0]=0xff;
    crc_32bit[1]=0xff;
    crc_32bit[2]=0xff;
    crc_32bit[3]=0xff;
    for (int i=0;i<mImageDataLength;i++) {
        int tmp;
        if(i>0x417 && i<0x41e)
        {
            tmp = [btAddressArrayList[6-(i-0x417)] intValue];
            versionData[i]=tmp;
        }
        tmp=versionData[i];
        if (i>63) {
            Byte crt[4];
            crt[0] = ((crc32_tab[(crc_32bit[0]^tmp)&0x000000ff]>>0)&0xff);
            crt[1] = ((crc32_tab[(crc_32bit[0]^tmp)&0x000000ff]>>8)&0xff);
            crt[2] = ((crc32_tab[(crc_32bit[0]^tmp)&0x000000ff]>>16)&0xff);
            crt[3] = ((crc32_tab[(crc_32bit[0]^tmp)&0x000000ff]>>24)&0xff);
            
            crc_32bit[0] = crc_32bit[1]&0x000000ff;
            crc_32bit[1] = crc_32bit[2]&0x000000ff;
            crc_32bit[2] = crc_32bit[3]&0x000000ff;
            crc_32bit[3] = 0;
            
            crc_32bit[0] = ((crc_32bit[0]&0x0000000ff)^(crt[0]&0x000000ff))&0x0000000ff;
            crc_32bit[1] = ((crc_32bit[1]&0x0000000ff)^(crt[1]&0x000000ff))&0x0000000ff;
            crc_32bit[2] = ((crc_32bit[2]&0x0000000ff)^(crt[2]&0x000000ff))&0x0000000ff;
            crc_32bit[3] = ((crc_32bit[3]&0x0000000ff)^(crt[3]&0x000000ff))&0x0000000ff;
        }
    }
    
    crc_32bit[0] = (crc_32bit[0]^0xff)&0x000000ff;
    crc_32bit[1] = (crc_32bit[1]^0xff)&0x000000ff;
    crc_32bit[2] = (crc_32bit[2]^0xff)&0x000000ff;
    crc_32bit[3] = (crc_32bit[3]^0xff)&0x000000ff;
    for (int j=0; j<4; j++) {
        int crc = crc_32bit[j] & 0xff;
        versionData[8+j] =crc;
    }
    crc_code = 0;
    for (int m=0; m<mImageDataLength;m++) {
        int tmp = versionData[m];
        crc_code ^= tmp;
    }
    NSLog(@"crc_code=%d",crc_code);
    int ret =crc_code & 0xff;
    versionData[mImageDataLength]=ret;
    mImageDataLength+=1;
    NSLog(@"mImageDataLength=%d",mImageDataLength);
}

-(NSArray *)handlerBTaddress
{
    
    NSMutableArray *writeArrayList=[NSMutableArray array];
    
    
    NSMutableString *valueString=[NSMutableString stringWithString:[MNFirmwareModel sharestance].number];
    valueString=[NSMutableString stringWithString:[valueString substringFromIndex:6]];
    [valueString appendString:@"-"];
    
    NSMutableString *tmpValue=[NSMutableString stringWithString:(NSString *)valueString];
    NSString *itemValue=[NSString string];
    while ([tmpValue rangeOfString:@"-"].location !=NSNotFound) {
        
        NSInteger location=[tmpValue rangeOfString:@"-"].location;
        itemValue = [tmpValue substringWithRange:NSMakeRange(location-2, location)];
        tmpValue =(NSMutableString *)[tmpValue substringFromIndex:location+1];
        int tmp;
        if ([[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"a"] || [[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"A"]) {
            tmp = 0x0a<<4;
            
        }else if ([[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"b"] || [[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"B"])
        {
            tmp = 0x0b<<4;
        }else if ([[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"c"] || [[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"C"])
        {
            tmp = 0x0c<<4;
        }else if ([[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"d"] || [[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"D"])
        {
            tmp = 0x0d<<4;
        }else if ([[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"e"] || [[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"E"])
        {
            tmp = 0x0e<<4;
        }else if ([[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"f"] || [[itemValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"F"])
        {
            tmp = 0x0f<<4;
        }else
        {
            tmp =[[itemValue substringWithRange:NSMakeRange(0,1)] intValue]<<4;
        }
        
        if ([[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"a"] || [[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"A"] ) {
            tmp |=0x0a;
        }else if ([[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"b"] || [[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"B"])
        {
            tmp |=0x0b;
        }
        else if ([[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"c"] || [[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"C"])
        {
            tmp |=0x0c;
        }
        else if ([[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"d"] || [[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"D"])
        {
            tmp |=0x0d;
        }
        else if ([[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"e"] || [[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"E"])
        {
            tmp |=0x0e;
        }
        else if ([[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"f"] || [[itemValue substringWithRange:NSMakeRange(1,1)] isEqualToString:@"F"])
        {
            tmp |=0x0f;
        }else
        {
            tmp |=[[itemValue substringWithRange:NSMakeRange(1,1)] intValue];
        }
        
        
        [writeArrayList addObject:[NSNumber numberWithInt:tmp]];
        
    }
    
    return (NSArray *)writeArrayList;
}

-(BOOL)setSuotaSettings:(NSString *)settings
{
    
    if ([settings rangeOfString:@":"].location==NSNotFound) {
        return false;
    }
    NSString *tmp=[settings substringWithRange:NSMakeRange(0,[settings rangeOfString:@":"].location)];
    NSString *tmp1=[NSString string];
    NSString *tmp2=[NSString string];
    if ([tmp isEqualToString:@"i2c"]) {
        if ([settings rangeOfString:@"scl=0x"].location==NSNotFound
            || [settings rangeOfString:@"sda=0x"].location==NSNotFound
            || [settings rangeOfString:@"blocksize="].location==NSNotFound
            || [settings rangeOfString:@"address="].location==NSNotFound
            ) {
            return false;
        }
        mMemoryType = I2C_TYPE;
        tmp=[settings substringWithRange:NSMakeRange([settings rangeOfString:@"scl=0x"].location+6,[settings rangeOfString:@"scl=0x"].location+8)];
        tmp1=[tmp substringWithRange:NSMakeRange(0,1)];
        tmp2=[tmp substringWithRange:NSMakeRange(1,1)];
        mI2cSclGpio= ([tmp1 intValue]<<4) | [tmp2 intValue];
        
        tmp=[settings substringWithRange:NSMakeRange([settings rangeOfString:@"sda=0x"].location+6,[settings rangeOfString:@"sda=0x"].location+8)];
        tmp1=[tmp substringWithRange:NSMakeRange(0,1)];
        tmp2=[tmp substringWithRange:NSMakeRange(1,1)];
        mI2cSdaGpio=([tmp1 intValue]<<4) | [tmp2 intValue];
        
        tmp=[settings substringWithRange:NSMakeRange([settings rangeOfString:@"address=0x"].location+6,[settings rangeOfString:@"sda=0x"].location+8)];
        tmp1=[tmp substringWithRange:NSMakeRange(0,1)];
        tmp2=[tmp substringWithRange:NSMakeRange(1,1)];
        mAddress=([tmp1 intValue]<<4) | [tmp2 intValue];
        
        tmp=[settings substringWithRange:NSMakeRange([settings rangeOfString:@"blocksize="].location+10,settings.length)];
        if (tmp) {
            mBlockSize=[tmp intValue];
        }else
        {
            mBlockSize=240;
        }
        
    }else if ([tmp isEqualToString:@"spi"])
    {
        if ([settings rangeOfString:@"blocksize="].location==NSNotFound
            || [settings rangeOfString:@"clk=0x"].location==NSNotFound
            || [settings rangeOfString:@"cs=0x"].location==NSNotFound
            || [settings rangeOfString:@"miso=0x"].location==NSNotFound
            || [settings rangeOfString:@"mosi=0x"].location==NSNotFound
            ) {
            return false;
        }
        
        mMemoryType=SPI_TYPE;
        tmp=[settings substringWithRange:NSMakeRange(([settings rangeOfString:@"clk=0x"].location+6),2)];
        tmp1=[tmp substringWithRange:NSMakeRange(0,1)];
        tmp2=[tmp substringWithRange:NSMakeRange(1,1)];
        mSpiClkGpio= ([tmp1 intValue]<<4) | [tmp2 intValue];
        
        tmp=[settings substringWithRange:NSMakeRange(([settings rangeOfString:@"cs=0x"].location+5),2)];
        tmp1=[tmp substringWithRange:NSMakeRange(0,1)];
        tmp2=[tmp substringWithRange:NSMakeRange(1,1)];
        mSpiCsGpio= ([tmp1 intValue]<<4) | [tmp2 intValue];
        tmp=[settings substringWithRange:NSMakeRange(([settings rangeOfString:@"mosi=0x"].location+7),2)];
        tmp1=[tmp substringWithRange:NSMakeRange(0,1)];
        tmp2=[tmp substringWithRange:NSMakeRange(1,1)];
        mSpiMosiGpio= ([tmp1 intValue]<<4) | [tmp2 intValue];
        
        tmp=[settings substringWithRange:NSMakeRange(([settings rangeOfString:@"miso=0x"].location+7),2)];
        tmp1=[tmp substringWithRange:NSMakeRange(0,1)];
        tmp2=[tmp substringWithRange:NSMakeRange(1,1)];
        mSpiMisoGpio= ([tmp1 intValue]<<4) | [tmp2 intValue];
        
        tmp=[settings substringWithRange:NSMakeRange(([settings rangeOfString:@"blocksize="].location+10),3)];
        if (tmp) {
            mBlockSize=[tmp intValue];
        }else
        {
            mBlockSize=240;
        }
        
        DLog(@"setSuotaSettings,mSpiClkGpio=%d,mSpiCsGpio=%d,mSpiMosiGpio=%d,mSpiMisoGpio=%d,mBlockSize=%d",mSpiClkGpio,mSpiCsGpio,mSpiMosiGpio,mSpiMisoGpio,mBlockSize);
    }
    return true;
}

-(void)suotaWriteMemDev
{
    Byte mem_dev[4]={0};
    mSpotaWriteStatus=SPOTA_WRITE_MEM_DEV;
    if(mMemoryType==I2C_TYPE)
    {
        mem_dev[3]=0x12;
    }else if (mMemoryType == SPI_TYPE)
    {
        mem_dev[3]=0x13;
    }
    NSData *data=[NSData dataWithBytes:mem_dev length:4];
    
    if (client.periperal && client.periperal.state == CBPeripheralStateConnected && client.spota_mem_dev_ch) {
        NSLog(@"%@, sendData:%@, len=%d\n ", self, data, (int)data.length);
        [client.periperal writeValue:data forCharacteristic:client.spota_mem_dev_ch type:CBCharacteristicWriteWithResponse];
    }else
    {
        
    }
    
}

-(void)suotaWriteMemGpioMap
{
    Byte mem_gpio_map[4]={0};
    if (mMemoryType ==I2C_TYPE) {
        mem_gpio_map[0]=mI2cSdaGpio;
        mem_gpio_map[1]=mI2cSclGpio;
        mem_gpio_map[2]=mAddress;
    }else if (mMemoryType == SPI_TYPE)
    {
        mem_gpio_map[0]=mSpiClkGpio;
        mem_gpio_map[1]=mSpiCsGpio;
        mem_gpio_map[2]=mSpiMosiGpio;
        mem_gpio_map[3]=mSpiMisoGpio;
    }
    mSpotaWriteStatus=SPOTA_WRITE_GPIO_MAP;
    NSData *data=[NSData dataWithBytes:mem_gpio_map length:4];
    NSLog(@"spota_gpio_map_ch=%@",client.spota_gpio_map_ch);
    
    if (client.periperal && client.periperal.state == CBPeripheralStateConnected && client.spota_gpio_map_ch) {
        NSLog(@"%@, sendData:%@, len=%d\n ", self, data, (int)data.length);
        [client.periperal writeValue:data forCharacteristic:client.spota_gpio_map_ch type:CBCharacteristicWriteWithResponse];
        
    }
    
}

-(void)suotaWriteDataLen:(int)datalen
{
    Byte len[2]={0};
    len[0]=(datalen & 0xff);
    len[1]=((datalen>>8) & 0xff);
    mSpotaWriteStatus=SPOTA_WRITE_PATH_LEN;
    NSData *data=[NSData dataWithBytes:len length:2];
    if (client.periperal && client.periperal.state == CBPeripheralStateConnected && client.spota_patch_len_ch) {
        NSLog(@"%@, sendData:%@, len=%d\n ", self, data, (int)data.length);
        [client.periperal writeValue:data forCharacteristic:client.spota_patch_len_ch type:CBCharacteristicWriteWithResponse];
    }
    
}

-(void)suotaWriteChunk
{
    Byte temp[20]={0};
    
    NSLog(@"mBlockOffset+mChunckOffset=%d",mBlockOffset+mChunckOffset);
    for (int i=0;i<mChunckLength; i++) {
        temp[i] =versionData[mBlockOffset+mChunckOffset+i];
    }
    NSData *data=[NSData dataWithBytes:temp length:mChunckLength];
    if (data.length==0) {
        return;
    }
    mSpotaWriteStatus = SPOTA_WRITE_PATH_DATA;
    if (client.periperal && client.periperal.state == CBPeripheralStateConnected && client.spota_patch_data_ch) {
        NSLog(@"%@, sendData:%@, len=%d\n ", self, data, (int)data.length);
        [client.periperal writeValue:data forCharacteristic:client.spota_patch_data_ch type:CBCharacteristicWriteWithResponse];
    }
    
    [self nextChunk];
}

-(void)suotaWriteEnd
{
    Byte endCode[4]={0};
    endCode[3]=0xfe;
    mSpotaWriteStatus=SPOTA_WRITE_SUCESS;
    NSData *data=[NSData dataWithBytes:endCode length:4];
    if (client.periperal && client.periperal.state == CBPeripheralStateConnected && client.spota_mem_dev_ch) {
        NSLog(@"%@, sendData:%@, len=%d\n ", self, data, (int)data.length);
        [client.periperal writeValue:data forCharacteristic:client.spota_mem_dev_ch type:CBCharacteristicWriteWithResponse];
    }
    
}
-(void)nextChunk
{
    mChunckOffset += mChunckLength;
    mChunckLength = (mBlockLength - mChunckOffset) > mChunckSize ? mChunckSize
				: (mBlockLength - mChunckOffset);
}


-(BOOL)isLastBlock
{return (mBlockOffset + mBlockLength) == mImageDataLength;
    
}

-(BOOL)isLastChunk
{
    return (mChunckOffset + mChunckLength) == mBlockLength;
}

-(void)nextBlock
{
    mBlockOffset += mBlockLength;
    mBlockLength = (mImageDataLength - mBlockOffset) > mBlockSize ? mBlockSize
				: (mImageDataLength - mBlockOffset);
}

-(void)onSuotaServiceStatusChange:(CBCharacteristic *)characteristic
{
    NSLog(@"Rev:%@  Length:%d uuid=%@",characteristic.value,(int)characteristic.value.length,characteristic.UUID);
    int length = (int)[characteristic.value length];
    Byte temp[length];
    [characteristic.value getBytes:temp length:length];
    
    int tmp =temp[0] & 0xff;
    DLog(@"onSpotaServiceStatusChange=%02x",tmp);
    DLog(@"mSpotaWriteStatus=%x",mSpotaWriteStatus);
    
    switch (temp[0]) {
        case SPOTAR_SRV_EXIT:
        case SPOTAR_CRC_ERR:
        case SPOTAR_PATCH_LEN_ERR:
        case SPOTAR_EXT_MEM_WRITE_ERR:
        case SPOTAR_INT_MEM_ERR:
        case SPOTAR_INVAL_MEM_TYPE:
        case SPOTAR_APP_ERROR:
        case SPOTAR_INVAL_IMG_BANK:
        case SPOTAR_INVAL_IMG_HDR:
        case SPOTAR_INVAL_IMG_SIZE:
        case SPOTAR_SAME_IMG_ERR:
        case SPOTAR_EXT_MEM_READ_ERR:
        case SPOTAR_INVAL_PRODUCT_HDR:
        {
            DLog(@"update Error,errcode=%x",tmp);
            
            upgradeFailureBlock_(@"固件不完整");
            
        }
            break;
        case SPOTAR_CMP_OK:
            
        {
            if(mSpotaWriteStatus == SPOTA_WRITE_PATH_DATA)
            {
                upgradeProgressBlock_(100*(mBlockOffset+mChunckOffset)/mImageDataLength);
                [self nextBlock];
                if ([self isLastBlock]) {
                    if (!mIsWriteLastLen) {
                        mIsWriteLastLen=true;
                        [self suotaWriteDataLen:mBlockLength];
                    }else
                    {
                        [client.periperal readValueForCharacteristic:client.spota_mem_info_ch];
                    }
                }else
                {
                    mIsLastChunk = false;
                    mChunckOffset = 0;
                    mChunckLength = (mBlockLength - mChunckOffset) > mChunckSize ? mChunckSize
                    : (mBlockLength - mChunckOffset);
                    [self suotaWriteChunk];
                }
            }
        }
            break;
        default:
            break;
    }
    
}



#pragma mark ---------------MNBleBaseServiceDialogOtaUpgradeDelegate-----------------------
-(void)receviceUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:SPOTA_SERV_STATUS_UUID]]) {
        [self onSuotaServiceStatusChange:characteristic];
    }
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:SPOTA_MEM_INFO_UUID]]) {
        [self suotaWriteEnd];
    }
}

-(void)receviceWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        DLog(@"error=%@",[error localizedDescription]);
        if (mSpotaWriteStatus==SPOTA_WRITE_SUCESS) {
            upgradeSucBlock_(@"dialogOTA升级成功");
        }
        
    }else
    {
        switch (mSpotaWriteStatus) {
            case SPOTA_WRITE_MEM_DEV:
            {
                [self suotaWriteMemGpioMap];
            }
                break;
            case SPOTA_WRITE_GPIO_MAP:
            {
                [self suotaWriteDataLen:mBlockSize];
                mBlockOffset = 0;
                mBlockLength = (mImageDataLength - mBlockOffset) > mBlockSize ? mBlockSize
                : (mImageDataLength - mBlockOffset);
            }
                break;
            case SPOTA_WRITE_PATH_LEN:
            {
                upgradeProgressBlock_(0);
                mChunckOffset=0;
                mChunckLength = (mBlockLength - mChunckOffset) > mChunckSize ? mChunckSize
                : (mBlockLength - mChunckOffset);
                mIsLastChunk = false;
                [self suotaWriteChunk];
                
            }
                break;
            case SPOTA_WRITE_PATH_DATA:
            {
                if (!mIsLastChunk) {
                    if ([self isLastChunk]) {
                        mIsLastChunk=true;
                    }
                }
                [self suotaWriteChunk];
            }
                break;
            case SPOTA_WRITE_SUCESS:
            {
                upgradeSucBlock_(@"dialogOTA升级成功");
            }
                break;
            default:
                break;
        }
    }
}


@end
