const Koa = require('koa');
const Router = require('koa-router');
const cors = require('@koa/cors');
const koaBody = require('koa-body');
const json = require('koa-json');
const app = new Koa();
const router = new Router();

router.prefix('/api')

//路由拦截
router.post('/detectionpose', async (ctx) => {
    let { body } = ctx.request; // es6的写法把ctx.request请求体的所有方法都放到body对象里面去
    // console.log(ctx.request);
    
    //console.log(body.poseData);
    let list = [];
    let postData = body.poseData;
    postData.forEach(item => {
        list.push(strToJson(item))
    });

    let aa = {};
    aa.status = 200;
    aa.data = '操作成功';
    ctx.body = aa;
    
    console.log(list);
})

app.use(koaBody())
app.use(cors()) 

app.use(json({pretty:false, param:'pretty'}));

app.use(router.routes())
    .use(router.allowedMethods())   //把前面所有定义的方法添加到app应用上去

    app.listen(3002);


function strToJson(str) {
    var json = eval('(' + str + ')');
    return json;
}